import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS4 Remote Installer',
      theme: ThemeData.dark(),
      home: const InstallerPage(),
    );
  }
}

class InstallerPage extends StatefulWidget {
  const InstallerPage({Key? key}) : super(key: key);

  @override
  _InstallerPageState createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage> {
  final TextEditingController _ipController = TextEditingController(text: '10.16.250.133');
  HttpServer? _localServer;
  String? _selectedFilePath;
  String _statusMessage = 'جاهز - يرجى اختيار ملف PKG';
  bool _isHosting = false;

  @override
  void initState() {
    super.initState();
    _startLocalServer();
  }

  Future<void> _startLocalServer() async {
    try {
      final router = shelf_router.Router();

      router.get('/pkg', (shelf.Request request) {
        try {
          if (_selectedFilePath == null) {
            return shelf.Response.notFound('No file selected');
          }
          
          File file = File(_selectedFilePath!);
          if (!file.existsSync()) {
            return shelf.Response.notFound('File does not exist on disk');
          }

          int length = file.lengthSync();
          var stream = file.openRead();

          return shelf.Response.ok(
            stream,
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Length': length.toString(),
              'Accept-Ranges': 'bytes',
            },
          );
        } catch (e) {
          return shelf.Response.internalServerError(body: 'Error: $e');
        }
      });

      final info = NetworkInfo();
      String? localIp = await info.getWifiIP() ?? '127.0.0.1';

      _localServer = await shelf_io.serve(router.call, localIp, 8080);
      setState(() {
        _isHosting = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في تشغيل السيرفر المحلي: $e';
      });
    }
  }

  Future<void> _pickAndSendToPS4() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        
        if (!filePath.toLowerCase().endsWith('.pkg')) {
          setState(() {
            _statusMessage = 'خطأ: يرجى اختيار ملف يحمل امتداد .pkg حصراً';
          });
          return;
        }

        setState(() {
          _selectedFilePath = filePath;
          _statusMessage = 'جاري تجهيز الرابط وإرساله للـ PS4...';
        });

        String ps4Ip = _ipController.text.
