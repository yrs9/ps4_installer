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
      title: 'PS4 Installer',
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
  String? downloadUrl;
  bool busy = false;

  Future<void> choosePkg() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pkg'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        pkgFile = File(result.files.single.path!);
        status = 'تم اختيار الملف: ${result.files.single.name}';
      });
    } catch (e) {
      setState(() => status = 'خطأ: $e');
    }
  }

  Future<void> startServer() async {
    if (pkgFile == null) {
