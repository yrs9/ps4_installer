import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 Package Installer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  String ps4Ip = '';
  String status = 'جاهز للاستخدام';
  String? selectedFilePath;
  HttpServer? server;

  Future<void> choosePkg() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pkg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFilePath = result.files.single.path;
          status = 'تم اختيار الملف: ${result.files.single.name}';
        });
      }
    } catch (e) {
      setState(() {
        status = 'خطأ في اختيار الملف: $e';
      });
    }
  }

  Future<void> startServerAndInstall() async {
    if (selectedFilePath == null) {
      setState(() {
        status = 'يرجى اختيار ملف PKG أولاً!';
      });
      return;
    }

    if (ps4Ip.isEmpty) {
      setState(() {
        status = 'يرجى أدخال عنوان IP الخاص بالـ PS4!';
      });
      return;
    }

    try {
      final file = File(selectedFilePath!);
      final router = Router();

      router.get('/pkg', (Request request) {
        return Response.ok(
          file.openRead(),
          headers: {
            'content-type': 'application/octet-stream',
            'content-length': file.lengthSync().toString(),
          },
        );
      });

      server?.close(force: true);
      server = await shelf_io.serve(
        router.call,
        InternetAddress.anyIPv4,
        8080,
      );

      final myIp = await _getLocalIp();
      final fileUrl = 'http://$myIp:8080/pkg';

      setState(() {
        status = 'جاري إرسال طلب التثبيت إلى الـ PS4...';
      });

      final response = await http.post(
        Uri.parse('http://$ps4Ip:12800/api/install'),
        body: '{"type":"direct","packages":["$fileUrl"]}',
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          status = 'تم إرسال الأوامر بنجاح! بدأ التثبيت على الـ PS4.';
        });
      } else {
        setState(() {
          status = 'فشل الـ PS4 في قبول التثبيت. كود الاستجابة: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        status = 'حدث خطأ: $e';
      });
    }
  }

  Future<String> _getLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  @override
  void dispose() {
    server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PS4 PKG Installer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'عنوان IP الخاص بالـ PS4',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ps4Ip = value;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: choosePkg,
              child: const Text('اختر ملف PKG'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: startServerAndInstall,
              child: const Text('تثبيت على الـ PS4'),
            ),
            const SizedBox(height: 24),
            Text(
              status,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
