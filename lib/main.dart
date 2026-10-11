import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

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
  final TextEditingController _pathController = TextEditingController();
  
  HttpServer? _localServer;
  String _statusMessage = 'السيرفر المحلي جاهز على البورت 8080';
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
          String filePath = _pathController.text.trim();
          if (filePath.isEmpty) {
            return shelf.Response.notFound('No file path provided');
          }
          
          File file = File(filePath);
          if (!file.existsSync()) {
            return shelf.Response.notFound('File does not exist at path: $filePath');
          }

          int fileLength = file.lengthSync();
          
          String? rangeHeader = request.headers['range'];
          int start = 0;
          int end = fileLength - 1;

          if (rangeHeader != null) {
            try {
              final parts = rangeHeader.replaceFirst('bytes=', '').split('-');
              start = int.parse(parts[0]);
              if (parts.length > 1 && parts[1].isNotEmpty) {
                end = int.parse(parts[1]);
              }
            } catch (_) {}
          }

          int contentLength = end - start + 1;
          var stream = file.openRead(start, end + 1);

          return shelf.Response(
            rangeHeader != null ? 206 : 200,
            body: stream,
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Length': contentLength.toString(),
              'Accept-Ranges': 'bytes',
              if (rangeHeader != null)
                'Content-Range': 'bytes $start-$end/$fileLength',
            },
          );
        } catch (e) {
          return shelf.Response.internalServerError(body: 'Error: $e');
        }
      });

      _localServer = await shelf_io.serve(router.call, '0.0.0.0', 8080);
      setState(() {
        _isHosting = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في تشغيل السيرفر: $e';
      });
    }
  }

  Future<String?> _getPhoneIpAddress() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          String ip = addr.address;
          if (ip.startsWith('10.') || ip.startsWith('192.') || ip.startsWith('172.')) {
            return ip;
          }
        }
      }
    }
    return null;
  }

  Future<void> _sendToPS4() async {
    try {
      String filePath = _pathController.text.trim();
      
      if (filePath.isEmpty) {
        setState(() {
          _statusMessage = 'خطأ: يرجى كتابة أو لصق مسار ملف الـ PKG';
        });
        return;
      }

      if (!filePath.toLowerCase().endsWith('.pkg')) {
        setState(() {
          _statusMessage = 'خطأ: المسار يجب أن ينتهي بـ .pkg';
        });
        return;
      }

      File file = File(filePath);
      if (!file.existsSync()) {
        setState(() {
          _statusMessage = 'خطأ: الملف غير موجود في هذا المسار!';
        });
        return;
      }

      setState(() {
        _statusMessage = 'جاري إرسال رابط اللعبة للبلايستيشن...';
      });

      String? phoneIp = await _getPhoneIpAddress();
      if (phoneIp == null) {
        setState(() {
          _statusMessage = 'خطأ: لم يتم التعرف على آي بي الهوتسبوت';
        });
        return;
      }

      String ps4Ip = _ipController.text.trim();
      String pkgUrl = 'http://$phoneIp:8080/pkg';

      var uri = Uri.parse('http://$ps4Ip:12800/api/install');
      
      var response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "type": "direct",
          "packages": [pkgUrl]
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'تم
