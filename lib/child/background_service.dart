import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:app_usage/app_usage.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:call_log/call_log.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:intl/intl.dart';
import '../../../firebase_options.dart';
import 'package:network_info_plus/network_info_plus.dart';

StreamSubscription<DocumentSnapshot>? firestoreSubscription;
StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
bool isSosTriggered = false;

String _normalizePhoneNumber(String number) {
  String digitsOnly = number.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length > 10) {
    return digitsOnly.substring(digitsOnly.length - 10);
  }
  return digitsOnly;
}

Future<String?> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('childDeviceUID');
}

Future<void> performSosAction() async {
  if (isSosTriggered) return;
  isSosTriggered = true;
  print('*** SOS TRIGGERED! ***');
  final deviceId = await getDeviceId();
  if (deviceId == null) {
    print('*** SOS FAILED: Device ID null ***');
    isSosTriggered = false; // Reset trigger
    return;
  }

  GeoPoint? sosLocation;
  String? sosAddress; // <-- Variable to hold the address

  try {
    // 1. Attempt to get current location
    if (await Permission.location.isGranted ||
        await Permission.locationAlways.isGranted) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 3),
      );
      sosLocation = GeoPoint(pos.latitude, pos.longitude);
      print('*** SOS Location Acquired: $sosLocation ***');

      // --- NEW: REVERSE GEOCODING ---
      try {
        // 2. Turn coordinates into a street address
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          // Create a simple, readable address
          sosAddress = "${p.name}, ${p.locality}, ${p.country}";
          print('*** SOS Address Acquired: $sosAddress ***');
        }
      } catch (e) {
        print('*** SOS: Geocoding failed: $e ***');
        sosAddress = null; // Failed to get address
      }
      // --- END NEW ---
    } else {
      print('*** SOS: Location permission not granted. ***');
    }
  } catch (e) {
    print('*** SOS: Failed to get location: $e ***');
  }

  try {
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId);

    // 3. Update the main document for the immediate alert
    await docRef.update({
      'sos_trigger': true,
      'lastSosTime': FieldValue.serverTimestamp(),
      if (sosLocation != null) 'lastSosLocation': sosLocation,
      if (sosAddress != null) 'lastSosAddress': sosAddress, // <-- Save address
    });
    print('*** FIRESTORE SOS TRIGGER SET ***');

    // 4. Create a new entry in the history log
    // ...
    await docRef.collection('sos_alerts').add({
      'timestamp': FieldValue.serverTimestamp(),
      'location': sosLocation, // <-- Saves the GeoPoint
      'address': sosAddress, // <-- Saves the Address String
    });
    // ...
    print('*** FIRESTORE SOS HISTORY LOGGED ***');
  } catch (e) {
    print('*** FIRESTORE SOS UPDATE FAILED: $e ***');
  }

  // Reset trigger after a delay
  Future.delayed(const Duration(seconds: 3), () => isSosTriggered = false);
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.child);

  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((event) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((event) => service.setAsBackgroundService());
  }

  final deviceId = await getDeviceId();
  if (deviceId == null) {
    print('Device ID is null, stopping service.');
    service.invoke('stopSelf');
    return;
  }

  // vvv --- ADDED LISTENER FOR CLIPBOARD RESULT --- vvv
  service.on('clipboardResult').listen((event) async {
    print("SERVICE: Received clipboard result from main thread.");
    final clipboardText = event?['text'];
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId);

    // This update is now safe and will stop the loop
    await docRef.update({
      'clipboardText': clipboardText ?? 'Clipboard is empty.',
      'clipboardLastUpdated': FieldValue.serverTimestamp(),
      'requestClipboard': false,
    });
    print("--- Clipboard fetch complete. Flag reset. ---");
  });
  // ^^^ ------------------------------------------ ^^^

  // Notification listener removed

  double shakeThreshold = 12.0;
  DateTime? lastShakeTime;
  accelerometerSubscription?.cancel();
  accelerometerSubscription = accelerometerEventStream().listen((event) {
    double x = event.x, y = event.y, z = event.z;
    double acceleration = (x * x + y * y + z * z) / (9.8 * 9.8);
    if (acceleration > shakeThreshold) {
      final now = DateTime.now();
      if (lastShakeTime == null ||
          now.difference(lastShakeTime!).inSeconds > 3) {
        lastShakeTime = now;
        performSosAction();
      }
    }
  }, onError: (e) => print('*** ACCELEROMETER ERROR: $e ***'));

  await firestoreSubscription?.cancel();
  firestoreSubscription = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId)
      .snapshots()
      .listen((snapshot) async {
        if (!snapshot.exists) {
          print('--- Parent deleted doc. Stopping service. ---');
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('childDeviceUID');
          await accelerometerSubscription?.cancel();
          await firestoreSubscription?.cancel();
          service.invoke('stopSelf');
          return;
        }

        final data = snapshot.data()!;
        final docRef = FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId);

        // vvv --- MODIFIED CLIPBOARD REQUEST --- vvv
        if (data.containsKey('requestClipboard') &&
            data['requestClipboard'] == true) {
          print("--- Request: Clipboard ---"); // This will stop spamming
          // Ask the main thread to get the clipboard (safe)
          service.invoke('getClipboard');
          // The response will be handled by the 'clipboardResult' listener
          // We no longer crash here
        }
        // ^^^ ---------------------------------- ^^^

        // --- THIS IS THE UPDATED LOGIC ---

        // BLOCK 1: For the "App Usage Stats" tile (app-by-app)
        if (data.containsKey('requestAppUsage') &&
            data['requestAppUsage'] == true) {
          print("--- Request: App Usage (Today, 24h, 30d-Total) ---");
          Future.wait([
                fetchAndUploadTodayAppUsage(deviceId),
                fetchAndUploadAppUsageForDuration(
                  deviceId,
                  const Duration(hours: 24),
                  'last_24h_stats',
                ),
                fetchAndUploadAppUsageForDuration(
                  deviceId,
                  const Duration(days: 30),
                  'last_30d_stats', // Your original 30-day total
                ),
              ])
              .then((_) async {
                await docRef.update({'requestAppUsage': false});
                print("--- App Usage fetches complete. Flag reset. ---");
              })
              .catchError((e) async {
                print("--- Error during App Usage fetches: $e ---");
                try {
                  await docRef.update({'requestAppUsage': false});
                } catch (_) {}
              });
        }

        // BLOCK 2: For the NEW "Screen Time Report" tile (30-day list)
        if (data.containsKey('requestScreenTimeReport') &&
            data['requestScreenTimeReport'] == true) {
          print("--- Request: Screen Time Report (30-Day List) ---");
          _fetchAndUploadDailyReports(deviceId)
              .then((_) async {
                await docRef.update({'requestScreenTimeReport': false});
                print("--- Screen Time Report fetch complete. Flag reset. ---");
              })
              .catchError((e) async {
                print("--- Error during Screen Time Report fetch: $e ---");
                try {
                  await docRef.update({'requestScreenTimeReport': false});
                } catch (_) {}
              });
        }

        if (data.containsKey('requestCallLog') &&
            data['requestCallLog'] == true) {
          print("--- Request: Call Log ---");
          await fetchAndUploadCallLog(deviceId);
          await docRef.update({'requestCallLog': false});
        }
        if (data.containsKey('requestSmsLog') &&
            data['requestSmsLog'] == true) {
          print("--- Request: SMS Log ---");
          await fetchAndUploadSmsLog(deviceId);
          await docRef.update({'requestSmsLog': false});
        }
        if (data.containsKey('requestContacts') &&
            data['requestContacts'] == true) {
          print("--- Request: Contacts ---");
          await fetchAndUploadContacts(deviceId);
          await docRef.update({'requestContacts': false});
        }
        if (data.containsKey('requestInstalledApps') &&
            data['requestInstalledApps'] == true) {
          print("--- Request: Installed Apps ---");
          await fetchAndUploadInstalledApps(deviceId);
          await docRef.update({'requestInstalledApps': false});
        }
      });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final currentDeviceId = await getDeviceId();
    if (currentDeviceId == null) {
      timer.cancel();
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(currentDeviceId);

    try {
      final battery = Battery();
      final connectivity = Connectivity();
      final batteryLevel = await battery.batteryLevel;
      final ringerStatus = await SoundMode.ringerModeStatus;
      final connectivityResult = await connectivity.checkConnectivity();

      String internetStatus = 'Offline';
      String? wifiSsid;
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        internetStatus = 'WiFi';
        try {
          final wifiName = await NetworkInfo().getWifiName();
          wifiSsid = wifiName?.replaceAll('"', '');
        } catch (e) {
          print('Error getting WiFi name: $e');
          wifiSsid = 'WiFi';
        }
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        internetStatus = 'Mobile';
      }

      await docRef.update({
        'batteryLevel': batteryLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
        'ringerMode': ringerStatus.name,
        'internetStatus': internetStatus,
        'wifiSsid': wifiSsid,
      });
    } catch (e) {
      print('STATS TIMER ERROR: $e');
    }
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final currentDeviceId = await getDeviceId();
    if (currentDeviceId == null) {
      timer.cancel();
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(currentDeviceId);
    try {
      if (await Permission.locationAlways.isGranted) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        await docRef.update({
          'currentLocation': GeoPoint(pos.latitude, pos.longitude),
          'locationLastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('LIVE LOC TIMER ERROR: $e');
    }
  });

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final currentDeviceId = await getDeviceId();
    if (currentDeviceId == null) {
      timer.cancel();
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(currentDeviceId);
    try {
      if (await Permission.locationAlways.isGranted) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        await docRef.collection('location_history').add({
          'location': GeoPoint(pos.latitude, pos.longitude),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('LOC HISTORY TIMER ERROR: $e');
    }
  });
}

Future<void> fetchAndUploadAppUsageForDuration(
  String deviceId,
  Duration duration,
  String docName,
) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('APP USAGE FETCH ($docName): Duration $duration');
  try {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(duration);
    List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
      startDate,
      endDate,
    );
    Map<String, Duration> aggregatedUsage = {};
    Map<String, DateTime> lastForegroundMap = {};
    for (var info in usageList) {
      if (info.usage.inMinutes > 0) {
        aggregatedUsage.update(
          info.packageName,
          (v) => v + info.usage,
          ifAbsent: () => info.usage,
        );
        lastForegroundMap.update(
          info.packageName,
          (v) => info.lastForeground.isAfter(v) ? info.lastForeground : v,
          ifAbsent: () => info.lastForeground,
        );
      }
    }
    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      false,
      false,
    );
    Map<String, String> appNames = {
      for (var app in installedApps) app.packageName: app.name,
    };
    List<Map<String, dynamic>> appData = [];
    aggregatedUsage.forEach((pkg, dur) {
      appData.add({
        'appName': appNames[pkg] ?? pkg,
        'packageName': pkg,
        'totalUsageMinutes': dur.inMinutes,
        'lastForeground': lastForegroundMap[pkg]?.toIso8601String(),
      });
    });
    await docRef.collection('app_usage').doc(docName).set({
      'updatedAt': FieldValue.serverTimestamp(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'apps': appData,
    });
    print('APP USAGE FETCH ($docName): Upload complete.');
  } catch (e) {
    print('APP USAGE FETCH ($docName) ERROR: $e');
  }
}

Future<void> fetchAndUploadTodayAppUsage(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('APP USAGE FETCH (Today)');
  try {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    List<AppUsageInfo> usageList = await AppUsage().getAppUsage(startDate, now);
    Map<String, Duration> aggregatedUsage = {};
    Map<String, DateTime> lastForegroundMap = {};
    for (var info in usageList) {
      if (info.usage.inMinutes > 0) {
        aggregatedUsage.update(
          info.packageName,
          (v) => v + info.usage,
          ifAbsent: () => info.usage,
        );
        lastForegroundMap.update(
          info.packageName,
          (v) => info.lastForeground.isAfter(v) ? info.lastForeground : v,
          ifAbsent: () => info.lastForeground,
        );
      }
    }
    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      false,
      false,
    );
    Map<String, String> appNames = {
      for (var app in installedApps) app.packageName: app.name,
    };
    List<Map<String, dynamic>> appData = [];
    aggregatedUsage.forEach((pkg, dur) {
      appData.add({
        'appName': appNames[pkg] ?? pkg,
        'packageName': pkg,
        'totalUsageMinutes': dur.inMinutes,
        'lastForeground': lastForegroundMap[pkg]?.toIso8601String(),
      });
    });
    await docRef.collection('app_usage').doc('today_stats').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'startDate': startDate.toIso8601String(),
      'endDate': now.toIso8601String(),
      'apps': appData,
    });
    print('APP USAGE FETCH (Today): Upload complete.');
  } catch (e) {
    print('APP USAGE FETCH (Today) ERROR: $e');
  }
}

Future<void> fetchAndUploadInstalledApps(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('INSTALLED APPS FETCH: Received request.');
  try {
    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      true,
      true,
    );
    print('INSTALLED APPS FETCH: Found ${installedApps.length} apps.');
    List<Map<String, dynamic>> appsData = [];
    for (var app in installedApps) {
      appsData.add({
        'appName': app.name,
        'packageName': app.packageName,
        'versionName': app.versionName,
        'versionCode': app.versionCode,
      });
    }
    await docRef.collection('installed_apps').doc('list').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'apps': appsData,
    });
    print('INSTALLED APPS FETCH: Upload complete.');
    await docRef.update({'requestInstalledApps': false});
  } catch (e) {
    print('INSTALLED APPS FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestInstalledApps': false});
  }
}

Future<void> fetchAndUploadContacts(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('CONTACTS FETCH: Received request.');
  try {
    var contactsPermission = await Permission.contacts.status;
    if (contactsPermission.isGranted) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: true,
      );
      List<Map<String, dynamic>> contactsData = [];
      for (var contact in contacts) {
        if (contact.phones.isNotEmpty) {
          contactsData.add({
            'displayName': contact.displayName,
            'phoneNumber': contact.phones.first.number,
          });
        }
      }
      await docRef.collection('contacts').doc('list').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'entries': contactsData,
      });
    } else {
      print('CONTACTS FETCH ERROR: Permission was not granted.');
    }
    await docRef.update({'requestContacts': false});
  } catch (e) {
    print('CONTACTS FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestContacts': false});
  }
}

Future<void> fetchAndUploadSmsLog(String deviceId) async {
  final SmsQuery query = SmsQuery();
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    var smsPermission = await Permission.sms.status;
    var contactsPermission = await Permission.contacts.status;
    Map<String, String> contactsMap = {};
    if (contactsPermission.isGranted) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String normalizedNumber = _normalizePhoneNumber(phone.number);
          if (normalizedNumber.isNotEmpty) {
            contactsMap[normalizedNumber] = contact.displayName;
          }
        }
      }
    }
    if (smsPermission.isGranted) {
      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      );
      List<Map<String, dynamic>> smsLogData = [];
      for (var message in messages) {
        if (message.address == null) continue;
        String normalizedAddress = _normalizePhoneNumber(message.address!);
        smsLogData.add({
          'name': contactsMap[normalizedAddress],
          'address': message.address,
          'body': message.body,
          'kind': message.kind?.name,
          'date': message.date,
        });
      }
      await docRef.collection('sms_log').doc('history').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'entries': smsLogData,
      });
    }
    await docRef.update({'requestSmsLog': false});
  } catch (e) {
    print('SMS LOG FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestSmsLog': false});
  }
}

Future<void> fetchAndUploadCallLog(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    Iterable<CallLogEntry> entries = await CallLog.get();
    List<Map<String, dynamic>> callLogData = [];
    for (var entry in entries) {
      callLogData.add({
        'name': entry.name,
        'number': entry.number,
        'callType': entry.callType?.name,
        'duration': entry.duration,
        'timestamp': entry.timestamp != null
            ? Timestamp.fromMillisecondsSinceEpoch(entry.timestamp!)
            : null,
      });
    }
    await docRef.collection('call_log').doc('history').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'entries': callLogData,
    });
    await docRef.update({'requestCallLog': false});
  } catch (e) {
    print('CALL LOG FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestCallLog': false});
  }
}

// ADD THIS FUNCTION TO THE END OF YOUR onStart FILE

Future<void> _fetchAndUploadDailyReports(String deviceId) async {
  print('DAILY REPORT (On-Demand): Starting 30-day loop...');
  final DateTime now = DateTime.now();
  List<Map<String, dynamic>> dailyReports = [];

  try {
    // Loop 30 times (for the last 30 days)
    for (int i = 0; i < 30; i++) {
      final DateTime dayToQuery = now.subtract(Duration(days: i));

      final DateTime startTime = DateTime(
        dayToQuery.year,
        dayToQuery.month,
        dayToQuery.day,
        0,
        0,
        0,
      );
      final DateTime endTime = DateTime(
        dayToQuery.year,
        dayToQuery.month,
        dayToQuery.day,
        23,
        59,
        59,
      );
      final String dateString = DateFormat('yyyy-MM-dd').format(startTime);

      // Get usage for this specific day
      final List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
        startTime,
        endTime,
      );

      // Calculate the total minutes
      int totalMinutes = 0;
      for (var info in usageList) {
        totalMinutes += info.usage.inMinutes;
      }

      // Add this day's data to our list
      dailyReports.add({'date': dateString, 'totalUsageMinutes': totalMinutes});
    }

    // After the loop, upload the entire list to a single document
    await FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId)
        .collection('app_usage')
        .doc('daily_30d_report') // <-- New document
        .set({
          'reports': dailyReports, // This is a LIST of all 30 days
          'updatedAt': FieldValue.serverTimestamp(),
        });

    print('DAILY REPORT (On-Demand): Upload complete.');
  } catch (e) {
    print('DAILY REPORT (On-Demand) ERROR: $e');
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}
