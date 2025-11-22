import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppBlockerScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const AppBlockerScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<AppBlockerScreen> createState() => _AppBlockerScreenState();
}

class _AppBlockerScreenState extends State<AppBlockerScreen> {
  late DocumentReference _installedAppsRef;
  late DocumentReference _blockedAppsRef;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _installedAppsRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId)
        .collection('installed_apps')
        .doc('list');

    _blockedAppsRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId)
        .collection('blocked_apps')
        .doc('list');
  }

  Future<void> _toggleBlockStatus(String packageName, bool isBlocked) async {
    try {
      if (isBlocked) {
        await _blockedAppsRef.set({
          'blocked_packages': FieldValue.arrayUnion([packageName])
        }, SetOptions(merge: true));
      } else {
        await _blockedAppsRef.update({
          'blocked_packages': FieldValue.arrayRemove([packageName])
        });
      }
    } catch (e) {
      print("Error toggling block status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating block status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Blocker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for an app...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _installedAppsRef.snapshots(),
        builder: (context, installedAppsSnapshot) {
          if (installedAppsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!installedAppsSnapshot.hasData || !installedAppsSnapshot.data!.exists) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No installed apps list found.\n\nPlease go back and press the "Refresh" button on the "Installed Apps" tile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final appData = installedAppsSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> installedApps = appData['apps'] ?? [];

          installedApps.sort((a, b) => (a['appName'] as String).toLowerCase().compareTo((b['appName'] as String).toLowerCase()));

          final List<dynamic> filteredApps = installedApps.where((app) {
            final String appName = (app['appName'] ?? '').toLowerCase();
            return appName.contains(_searchQuery);
          }).toList();


          return StreamBuilder<DocumentSnapshot>(
            stream: _blockedAppsRef.snapshots(),
            builder: (context, blockedAppsSnapshot) {
              
              List<String> blockedPackages = [];
              if (blockedAppsSnapshot.hasData && blockedAppsSnapshot.data!.exists) {
                final blockedData = blockedAppsSnapshot.data!.data() as Map<String, dynamic>;
                blockedPackages = List<String>.from(blockedData['blocked_packages'] ?? []);
              }

              return ListView.builder(
                itemCount: filteredApps.length,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
                  final String appName = app['appName'] ?? 'Unknown App';
                  final String packageName = app['packageName'] ?? '';

                  if (packageName.isEmpty) {
                    return SizedBox.shrink(); 
                  }

                  final bool isBlocked = blockedPackages.contains(packageName);

                  return SwitchListTile(
                    title: Text(appName),
                    subtitle: Text(packageName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    value: isBlocked,
                    activeColor: Colors.red,
                    onChanged: (bool newValue) {
                      _toggleBlockStatus(packageName, newValue);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}