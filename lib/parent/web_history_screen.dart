import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class WebHistoryScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const WebHistoryScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  Future<void> _launchURL(BuildContext context, String urlString) async {
    if (urlString.isEmpty) return;

    String finalUrl = urlString;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    try {
      final Uri url = Uri.parse(finalUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch this URL.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid URL format: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Web History?'),
        content: const Text(
            'This will permanently delete all recorded web history for this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        var collection = FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('web_history');
            
        var snapshots = await collection.get();
        
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Web history cleared.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error clearing history: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('$deviceName Web History'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: () => _confirmClearHistory(context),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('web_history')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No web history recorded yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String url = data['url'] ?? 'Unknown URL';
              final String packageName =
                  data['packageName'] ?? 'Unknown Browser';
              final Timestamp? timestamp = data['timestamp'];

              final String timeStr = timestamp != null
                  ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                  : 'Unknown Time';

              return Card(
                elevation: 0,
                color: Colors.grey[50],
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: const Icon(Icons.public, color: Colors.blueAccent),
                  ),
                  title: Text(
                    url,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(timeStr,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(packageName,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                  onTap: () => _launchURL(context, url),
                ),
              );
            },
          );
        },
      ),
    );
  }
}