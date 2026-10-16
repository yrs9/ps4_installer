import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS4 Remote Installer',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String _status = 'جاهز للاستخدام';
  HttpServer? _server;
  String _hostedFileUrl = '';
  final TextEditingController _ipController = TextEditingController();

  @override
  void dispose() {
    _server?.close();
    _ipController.dispose();
    super.dispose();
  }

  // دالة موثوقة لجلب آيباد الهاتف في الشبكة المحلية
  Future<String> _getLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4)) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.') || addr.address.startsWith('10.') || addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> _startServerAndPickFile() async {
    try {
      setState(() {
        _status = 'جاري اختيار الملف...';
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        File file = File(filePath);

        if (_server != null) {
          await _server!.close();
        }

        // تشغيل السيرفر على أي واجهة شبكة متاحة لتفادي مشاكل الأذونات
        _server = await io.serve((req) => const shelf.Response.ok(''), InternetAddress.anyIPv4, 8080);
        await _server!.close();

        final router = shelf_router.Router();
        router.get('/pkg', (shelf.Request request) {
          return shelf.Response.ok(file.openRead(), headers: {
            'Content-Type': 'application/octet-stream',
          });
        });

        // إعادة تشغيل السيرفر فعلياً لاستضافة الملف
        _server = await io.serve(router.call, InternetAddress.anyIPv4, 8080);
        
        String localIp = await _getLocalIp();
        setState(() {
          _hostedFileUrl = 'http://$localIp:8080/pkg';
          _status = 'تم استضافة الملف بنجاح\n$_hostedFileUrl';
        });
      } else {
        setState(() {
          _status = 'تم إلغاء اختيار الملف';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'خطأ في تشغيل السيرفر: $e';
      });
    }
  }

  Future<void> _sendToPS4() async {
    final ps4Ip = _ipController.text.trim();
    if (ps4Ip.isEmpty || _hostedFileUrl.isEmpty) {
      setState(() {
        _status = 'الرجاء إدخال آيباد الـ PS4 واختيار ملف PKG أولاً.';
      });
      return;
    }

    try {
      setState(() {
        _status = 'جاري إرسال أمر التثبيت للخلفية...';
      });

      final url = Uri.parse('http://$ps4Ip:12800/api/install');
      final response = await http.post(
        url,
        body: '{"type": "direct", "url": "$_hostedFileUrl"}',
      );

      if (response.statusCode == 200) {
        setState(() {
          _status = 'تم إرسال الأمر بنجاح! راقب إشعار التحميل على الـ PS4';
        });
      } else {
        setState(() {
          _status = 'فشل الرد من السوني: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'خطأ في الاتصال بالـ PS4: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PS4 Remote Installer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'أدخل آيباد بلايستيشن 4 (PS4 IP)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startServerAndPickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('اختر ملف PKG'),
