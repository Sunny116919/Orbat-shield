import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit_shield/child/child_auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.child);

  final service = FlutterBackgroundService();

  service.on('getClipboard').listen((event) async {
    print("MAIN THREAD: Received 'getClipboard' request from service.");
    String? clipboardText;
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      clipboardText = clipboardData?.text;
    } catch (e) {
      clipboardText = "Error reading clipboard: $e";
    }
    service.invoke('clipboardResult', {"text": clipboardText});
    print("MAIN THREAD: Sent clipboard text back to service.");
  });

  runApp(const ChildApp());
}

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Shield Child',
      home: ChildAuthWrapper(),
    );
  }
}
