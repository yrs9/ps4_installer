import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  runApp(const PS4InstallerApp());
}

class PS4InstallerApp extends StatelessWidget {
  const PS4InstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS4 PKG Installer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const InstallerHomePage(),
    );
  }
}

class InstallerHomePage extends StatefulWidget {
  const InstallerHomePage({super.key});

  @override
  State<InstallerHomePage> createState() => _InstallerHomePageState();
}

class _InstallerHomePageState extends State<InstallerHomePage> {
  String? _selectedFilePath;
  String? _fileName;
  bool _isServerRunning = false;
  HttpServer? _server;
  String _statusMessage = 'اختر ملف PKG وابدأ السيرفر محلياً';

  Future<void> _startServer() async {
    if (_selectedFilePath == null) {
      setState(() {
        _statusMessage = 'الرجاء اختيار ملف PKG أولاً!';
      });
      return;
    }

    try {
      var handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .handler((shelf.Request request) {
        final file = File(_selectedFilePath!);
        return shelf.Response.ok(
          file.openRead(),
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Disposition': 'attachment; filename="$_fileName"',
          },
        );
      });

      _server = await shelf_io.serve(handler, '0.0.0.0', 8080);
      setState(() {
        _isServerRunning = true;
        _statusMessage = 'السيرفر شغال على البورت 8080. أدخل آيبي هاتفك في الـ PS4 لبدء التثبيت.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في تشغيل السيرفر: $e';
      });
    }
  }

  Future<void> _stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      setState(() {
        _isServerRunning = false;
        _statusMessage = 'تم إيقاف السيرفر.';
      });
    }
  }

  Future<void> _pickPkgFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _fileName = result.files.single.name;
        _statusMessage = 'تم اختيار الملف: $_fileName';
      });
    }
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PS4 PKG Installer (Remote IP)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.games, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 10),
                    Text(
                      _fileName != null ? 'الملف: $_fileName' : 'لم يتم اختيار أي ملف PKG',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickPkgFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('اختيار ملف PKG من الهاتف'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
            ),
            const SizedBox(height: 12),
            if (!_isServerRunning)
              ElevatedButton.icon(
                onPressed: _startServer,
                icon: const Icon(Icons.play_arrow),
                label: const Text('تشغيل السيرفر المحلي'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopServer,
                
