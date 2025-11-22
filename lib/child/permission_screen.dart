import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_usage/app_usage.dart';
import 'package:geolocator/geolocator.dart';
import 'qr_scanner_screen.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:sound_mode/permission_handler.dart' as DndPermission;
import 'dart:io' show Platform;

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isCameraGranted = false;
  bool _isCallLogGranted = false;
  bool _isSmsGranted = false;
  bool _isContactsGranted = false;
  bool _isLocationGranted = false;
  bool _isBackgroundLocationGranted = false;
  bool _isGpsEnabled = false;
  bool _isBatteryOptimizationDisabled = false;
  bool _isDndAccessGranted = false;
  bool _isNotificationListenerGranted = false; 
    static const MethodChannel _notificationChannel = 
      MethodChannel('com.orbitshield.app/notifications');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final callLogStatus = await Permission.phone.status;
    final smsStatus = await Permission.sms.status;
    final contactsStatus = await Permission.contacts.status;
    final locationStatus = await Permission.location.status;
    final backgroundLocationStatus = await Permission.locationAlways.status;
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    final isBatteryOptDisabled =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled;
    
    final isDndGranted = await DndPermission.PermissionHandler.permissionsGranted;

    bool isNotifListenerGranted = false;
    if (Platform.isAndroid) {
      try {
        isNotifListenerGranted = await _notificationChannel.invokeMethod('isPermissionGranted');
      } catch (e) {
        print("Error checking notification permission: $e");
      }
    }

    setState(() {
      _isCameraGranted = cameraStatus.isGranted;
      _isCallLogGranted = callLogStatus.isGranted;
      _isSmsGranted = smsStatus.isGranted;
      _isContactsGranted = contactsStatus.isGranted;
      _isLocationGranted = locationStatus.isGranted;
      _isBackgroundLocationGranted = backgroundLocationStatus.isGranted;
      _isGpsEnabled = isGpsEnabled;
      _isBatteryOptimizationDisabled = isBatteryOptDisabled ?? false;
      _isDndAccessGranted = isDndGranted!;
      _isNotificationListenerGranted = isNotifListenerGranted;
    });
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
    _checkAllPermissions();
  }

  Future<void> _requestCallLogPermission() async {
    await Permission.phone.request();
    _checkAllPermissions();
  }

  Future<void> _requestSmsPermission() async {
    await Permission.sms.request();
    _checkAllPermissions();
  }

  Future<void> _requestContactsPermission() async {
    await Permission.contacts.request();
    _checkAllPermissions();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.location.request();
    _checkAllPermissions();
  }

  Future<void> _requestBackgroundLocationPermission() async {
    await Permission.locationAlways.request();
    _checkAllPermissions();
  }

  Future<void> _openBackgroundSettings() async {
    await openAppSettings();
  }

  Future<void> _openUsageSettings() async {
    AppUsage().getAppUsage(
      DateTime.now().subtract(const Duration(days: 1)),
      DateTime.now(),
    );
  }

  Future<void> _openGpsSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _requestBatteryOptimization() async {
    await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
  }

  Future<void> _requestDndAccess() async {
    await DndPermission.PermissionHandler.openDoNotDisturbSetting();
  }

  Future<void> _openAccessibilitySettings() async {
    if (Platform.isAndroid) {
      const AndroidIntent intent = AndroidIntent(
        action: 'android.settings.ACCESSIBILITY_SETTINGS',
      );
      await intent.launch();
    }
  }

  Future<void> _requestNotificationListenerPermission() async {
    if (Platform.isAndroid) {
      try {
        await _notificationChannel.invokeMethod('requestPermission');
      } catch (e) {
        print("Error requesting notification permission: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue =
        _isCameraGranted &&
        _isCallLogGranted &&
        _isSmsGranted &&
        _isContactsGranted &&
        _isLocationGranted &&
        _isGpsEnabled &&
        _isBackgroundLocationGranted &&
        _isBatteryOptimizationDisabled &&
        _isDndAccessGranted &&
        _isNotificationListenerGranted;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Setup Required',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please grant the following permissions to continue:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Camera Permission',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Needed to scan the QR code.'),
                      trailing: _isCameraGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestCameraPermission,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Call Log Permission',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Needed to see call history.'),
                      trailing: _isCallLogGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestCallLogPermission,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'SMS Permission',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Needed to read text messages.'),
                      trailing: _isSmsGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestSmsPermission,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Contacts Permission',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Needed to show contact names.'),
                      trailing: _isContactsGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestContactsPermission,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Location Permission',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Needed for location tracking.'),
                      trailing: _isLocationGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestLocationPermission,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'GPS / Location Service',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Must be enabled for tracking.'),
                      trailing: _isGpsEnabled
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _openGpsSettings,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Background Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Select "Allow all the time".'),
                      trailing: _isBackgroundLocationGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: !_isLocationGranted
                                  ? null
                                  : _requestBackgroundLocationPermission,
                              child: const Text('Allow'),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Background Activity',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Set to "No restrictions".'),
                      trailing: ElevatedButton(
                        onPressed: _openBackgroundSettings,
                        child: const Text('Settings'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'App Usage Access',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Needed to monitor screen time.'),
                      trailing: ElevatedButton(
                        onPressed: _openUsageSettings,
                        child: const Text('Settings'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Do Not Disturb Access',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          const Text('Needed to force ring on silent mode.'),
                      trailing: _isDndAccessGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestDndAccess,
                              child: const Text('Settings'),
                            ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Notification Access',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Needed to read notification history.',
                      ),
                      trailing: _isNotificationListenerGranted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestNotificationListenerPermission,
                              child: const Text('Settings'),
                            ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Accessibility Service',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Needed for App Blocker & Web History. Find "Orbit Shield" and enable it.',
                      ),
                      trailing: ElevatedButton(
                        onPressed: _openAccessibilitySettings,
                        child: const Text('Settings'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Disable Battery Optimization',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Find this app, tap it, and select "Don\'t optimize".',
                      ),
                      trailing: _isBatteryOptimizationDisabled
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            )
                          : ElevatedButton(
                              onPressed: _requestBatteryOptimization,
                              child: const Text('Settings'),
                            ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: !canContinue
                    ? null
                    : () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const QrScannerScreen(),
                          ),
                        );
                      },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}