import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:orbit_shield/parent/app_usage_screens.dart';
import 'package:orbit_shield/parent/clipboard_screen.dart';
import 'package:orbit_shield/parent/installed_app_screen.dart';
import 'package:orbit_shield/parent/location_screen.dart';
import 'package:orbit_shield/parent/sos_alert_history_screen.dart';
import 'call_history_screen.dart';
import 'sms_history_screen.dart';
import 'contacts_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const DeviceDetailScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  void initState() {
    super.initState();
    _triggerInitialFetchIfNeeded();
  }

  Future<void> _triggerInitialFetchIfNeeded() async {
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    if (!data.containsKey('initialFetchComplete') ||
        data['initialFetchComplete'] == false) {
      print('--- First time opening details. Triggering ALL data fetches. ---');
      await docRef.update({
        'requestAppUsage': true,
        // 'requestScreenTimeReport': true, // <-- REMOVED
        'requestCallLog': true,
        'requestSmsLog': true,
        'requestContacts': true,
        'requestInstalledApps': true,
      });
    }
  }

  Future<void> _requestData(String requestFlag) async {
    try {
      await FirebaseFirestore.instance
          .collection('child_devices')
          .doc(widget.deviceId)
          .update({requestFlag: true});
    } catch (e) {
      print("Failed to send request for $requestFlag: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Request Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.deviceName),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(widget.deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // --- Separate Flags ---
          final bool isFetchingAppUsage = data['requestAppUsage'] ?? false;
          // final bool isFetchingScreenTimeReport = ... // <-- REMOVED
          // ---

          final bool isFetchingCallLog = data['requestCallLog'] ?? false;
          final bool isFetchingSmsLog = data['requestSmsLog'] ?? false;
          final bool isFetchingContacts = data['requestContacts'] ?? false;
          final bool isFetchingInstalledApps =
              data['requestInstalledApps'] ?? false;
          final bool initialFetchWasDone =
              data['initialFetchComplete'] ?? false;
          final bool isFetchingClipboard = data['requestClipboard'] ?? false;

          if (!initialFetchWasDone &&
              !isFetchingAppUsage &&
              // !isFetchingScreenTimeReport && // <-- REMOVED
              !isFetchingCallLog &&
              !isFetchingSmsLog &&
              !isFetchingContacts &&
              !isFetchingInstalledApps) {
            try {
              FirebaseFirestore.instance
                  .collection('child_devices')
                  .doc(widget.deviceId)
                  .update({'initialFetchComplete': true});
            } catch (e) {
              print("Error marking initial fetch complete: $e");
            }
          }

          return ListView(
            children: [
              // --- TILE 1: Screen Time Report ---
              // <-- REMOVED

              // --- TILE 2: App Usage Stats ---
              _FeatureTile(
                title: 'App Usage Stats',
                subtitle: 'View usage by app: Today, 24h, 30d',
                icon: Icons.bar_chart,
                isLoading: isFetchingAppUsage, // <-- Uses its own flag
                onRefresh: () =>
                    _requestData('requestAppUsage'), // <-- Uses its own flag
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppUsageScreen(
                      deviceId: widget.deviceId,
                      deviceName: widget.deviceName,
                    ),
                  ),
                ),
              ),
              // --- Other Tiles ---
              _FeatureTile(
                title: 'Call History',
                subtitle: 'View incoming and outgoing calls',
                icon: Icons.call,
                isLoading: isFetchingCallLog,
                onRefresh: () => _requestData('requestCallLog'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallHistoryScreen(
                      deviceId: widget.deviceId,
                      deviceName: widget.deviceName,
                    ),
                  ),
                ),
              ),
              _FeatureTile(
                title: 'SMS History',
                subtitle: 'View sent and received messages',
                icon: Icons.sms,
                isLoading: isFetchingSmsLog,
                onRefresh: () => _requestData('requestSmsLog'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SmsHistoryScreen(
                      deviceId: widget.deviceId,
                      deviceName: widget.deviceName,
                    ),
                  ),
                ),
              ),
              _FeatureTile(
                title: 'Contacts',
                subtitle: 'View saved contacts',
                icon: Icons.contacts,
                isLoading: isFetchingContacts,
                onRefresh: () => _requestData('requestContacts'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContactsScreen(
                      deviceId: widget.deviceId,
                      deviceName: widget.deviceName,
                    ),
                  ),
                ),
              ),
              _FeatureTile(
                title: 'Installed Apps',
                subtitle: 'View all installed applications',
                icon: Icons.apps,
                isLoading: isFetchingInstalledApps,
                onRefresh: () => _requestData('requestInstalledApps'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InstalledAppsScreen(
                      deviceId: widget.deviceId,
                      deviceName: widget.deviceName,
                    ),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('SOS Alert History'),
                subtitle: const Text('View a log of all panic alerts'),
                leading: const Icon(Icons.warning_amber_rounded),
                trailing: const Icon(Icons.chevron_right),
                // onRefresh: () {
                //   // This is a log, so a manual refresh doesn't do much.
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     const SnackBar(
                //       content: Text('SOS history is updated automatically.'),
                //     ),
                //   );
                // },
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SosAlertHistoryScreen(
                      deviceId: widget.deviceId,
                      deviceName: widget.deviceName,
                    ),
                  ),
                ),
              ),
              // const Divider(),
              // _FeatureTile(
              //   title: 'View Clipboard',
              //   subtitle: 'See the most recent copied text',
              //   icon: Icons.content_paste,
              //   isLoading: isFetchingClipboard,
              //   onRefresh: () => _requestData('requestClipboard'),
              //   onTap: () => Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (context) => ClipboardScreen(
              //         deviceId: widget.deviceId,
              //         deviceName: widget.deviceName,
              //       ),
              //     ),
              //   ),
              // ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location Tracking'),
                subtitle: const Text('View current location and history'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationScreen(
                        deviceId: widget.deviceId,
                        deviceName: widget.deviceName,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLoading,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  State<_FeatureTile> createState() => __FeatureTileState();
}

class __FeatureTileState extends State<_FeatureTile> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _startLoadingSimulation();
    }
  }

  @override
  void didUpdateWidget(covariant _FeatureTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _startLoadingSimulation();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _stopLoadingSimulation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLoadingSimulation() {
    _timer?.cancel();
    setState(() {
      _progress = 0.0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 0.95) {
          _progress += 0.02;
        }
      });
    });
  }

  void _stopLoadingSimulation() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _progress = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            widget.icon,
            color: widget.isLoading
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
          ),
          title: Text(widget.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.subtitle),
              if (widget.isLoading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[300],
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.isLoading ? null : widget.onRefresh,
                tooltip: 'Refresh ${widget.title}',
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: widget.isLoading ? null : widget.onTap,
          enabled: !widget.isLoading,
        ),
        const Divider(),
      ],
    );
  }
}
