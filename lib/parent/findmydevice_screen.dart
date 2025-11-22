import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FindMyDeviceScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const FindMyDeviceScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<FindMyDeviceScreen> createState() => _FindMyDeviceScreenState();
}

class _FindMyDeviceScreenState extends State<FindMyDeviceScreen> {
  late DocumentReference _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId);
  }

  void _requestFindDevice() {
    try {
      _docRef.update({'requestFindDevice': true});
    } catch (e) {
      print("Failed to send Find My Device request: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find My Device'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          bool isFinding = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            isFinding = data['requestFindDevice'] ?? false;
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isFinding ? Icons.vibration_rounded : Icons.spatial_audio_rounded,
                  size: 150,
                  color: isFinding ? Colors.blue : Colors.grey[700],
                ),
                const SizedBox(height: 24),
                Text(
                  isFinding ? 'Ringing ${widget.deviceName}...' : 'Find ${widget.deviceName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This will make the child\'s device ring at full volume for 15 seconds, even if it is on silent.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: isFinding ? null : _requestFindDevice,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: isFinding ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: isFinding
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(width: 24),
                            Text('RINGING...'),
                          ],
                        )
                      : const Text('RING DEVICE'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}