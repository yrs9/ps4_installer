import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const PS4App());

class PS4App extends StatelessWidget {
  const PS4App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const InstallerPage(),
    );
  }
}

class InstallerPage extends StatefulWidget {
  const InstallerPage({super.key});

  @override
  State<InstallerPage> createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage> {
  File? pkgFile;
  HttpServer? server;
  String status = 'اختَر ملف PKG';
  String? url;

  Future<void> choosePkg() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) return;

      final picked = result.files.single;
      if (!picked.name.toLowerCase().endsWith('.pkg')) {
        setState(() => status = 'اختَر ملف PKG فقط');
        return;
      }

      setState(() {
        pkgFile = File(picked.path!);
        status
