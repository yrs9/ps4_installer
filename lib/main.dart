import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('PS4 Installer')),
        body: const Center(
          child: Text('Welcome to PS4 Remote Installer!'),
        ),
      ),
    );
  }
}
