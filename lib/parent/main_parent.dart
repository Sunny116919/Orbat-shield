import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:orbit_shield/firebase_options.dart';
import 'package:orbit_shield/parent/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.parent);
  runApp(const ParentApp());
}

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Shield Parent',
      home: AuthWrapper(),
    );
  }
}
