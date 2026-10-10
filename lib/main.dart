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
        if (_selectedFilePath == null) {
          return shelf.Response.notFound('File not found');
        }
        File file = File(_selectedFilePath!);
        if (!file.existsSync()) {
          return shelf.Response.notFound('File not found on disk');
        }
        
        final length = file.lengthSync();
        final stream = file.openRead();

        return shelf.Response.ok(
          stream,
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': length.toString(),
          },
        );
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
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        if (!file.path.toLowerCase().endsWith('.pkg')) {
          setState(() {
            _statusMessage = 'خطأ: يرجى اختيار ملف يحمل امتداد .pkg فقط';
          });
          return;
        }

        _selectedFilePath = file.path;
        String ps4Ip = _ipController.text.trim();
        
        final info = NetworkInfo();
        String? phoneIp = await info.getWifiIP();
        
        if (phoneIp == null) {
          setState(() {
            _statusMessage = 'خطأ: لم يتم التعرف على شبكة الواي فاي/الهوتسبوت';
          });
          return;
        }

        String pkgUrl = 'http://$phoneIp:8080/pkg';

        setState(() {
          _statusMessage = 'جاري إرسال الرابط للبلايستيشن...';
        });

        var uri = Uri.parse('http://$ps4Ip:12800/api/install');
        
        // إرسال الطلب بنفس هيكلية وطريقة سكريبت Node.js الصحيحة تماماً
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
            _statusMessage = 'تم إرسال الرابط بنجاح! السحب الفوري بدأ على PS4';
          });
        } else {
          setState(() {
            _statusMessage = 'خطأ من البلايستيشن: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ: $e';
      });
    }
  }

  @override
  void dispose() {
    _localServer?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF3B82F6);
    const Color backgroundColor = Color(0xFF121212);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('PS4 Remote Installer'),
        backgroundColor: Colors.black54,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _ipController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'PS4 IP Address',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isHosting ? _pickAndSendToPS4 : null,
              child: const Text(
                'اختر ملف PKG وابدأ السحب الفوري',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.amber),
            ),
          ],
        ),
      ),
    );
  }
}
