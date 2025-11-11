import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SosAlertHistoryScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const SosAlertHistoryScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'No date';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate().toLocal();
      return DateFormat('MMM d, yyyy \'at\' h:mm a').format(dt);
    }
    return 'Invalid date';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('SOS Alert History'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('sos_alerts') // Reading from the new log
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No SOS alerts have been recorded.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final entries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: entries.length,
            // ... inside your StreamBuilder
            itemBuilder: (context, index) {
              final entry = entries[index].data() as Map<String, dynamic>;
              // ...
              final GeoPoint? location =
                  entry['location']; // <-- Reads the GeoPoint
              final String? address = entry['address']; // <-- Reads the Address

              String locationString = "";

              if (address != null && address.isNotEmpty) {
                // 1. Shows address if it exists
                locationString = address;
              } else if (location != null) {
                // 2. Shows Lat/Lon if address doesn't exist but location does
                locationString =
                    'Lat: ${location.latitude.toStringAsFixed(4)}, Lon: ${location.longitude.toStringAsFixed(4)}';
              }
              // 3. Shows nothing if both are null
              // ...

              return ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: Text(
                  'SOS Alert Triggered',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatTimestamp(entry['timestamp'])),

                    // 5. Only show the Text widget if the string is not empty
                    if (locationString.isNotEmpty) Text(locationString),
                  ],
                ),
                // 6. Adjust list tile size based on content
                isThreeLine: locationString.isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}
