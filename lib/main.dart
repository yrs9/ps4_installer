import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  HttpServer? server;
  File? selectedFile;
  String status = 'اختر ملف PKG';
  String url = '';

  Future<void> selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pkg'],
      );

      if (result == null || result.files.single.path == null) return;

      selectedFile = File(result.files.single.path!);

      setState(() {
        status = 'تم اختيار الملف: ${result.files.single.name}';
      });
    } catch (e) {
      setState(() => status = 'خطأ: $e');
    }
  }

  Future<void> startServer() async {
    if (selectedFile == null) {
      setState(() => status = 'اختر ملف PKG أولاً');
      return;
    }

    try {
      await server?.close(force: true);

      server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        8080,
      );

      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? ip;

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.address.startsWith('192.') ||
              address.address.startsWith('10.') ||
              address.address.startsWith('172.')) {
            ip = address.address;
            break;
          }
        }
        if (ip != null) break;
      }

      if (ip == null) {
        await server?.close(force: true);
        server = null;
        setState(() => status = 'اتصل بشبكة Wi-Fi وحاول مجدداً');
        return;
      }

      url = 'http://$ip:8080/pkg';

      setState(() => status = 'الخادم يعمل: $url');

      server!.listen((request) async {
        if (request.uri.path != '/pkg' ||
            request.method != 'GET') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        try {
          final file = selectedFile!;
          final length = await file.length();

          request.response.headers
              .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
          request.response.headers.set(
            HttpHeaders.contentDispositionHeader,
            'attachment; filename="game.pkg"',
          );
          request.response.headers.contentLength = length;

          await request.response.addStream(file.openRead());
          await request.response.close();
        } catch (_) {
          request.response.statusCode =
              HttpStatus.internalServerError;
          await request.response.close();
        }
      });
    } catch (e) {
      setState(() => status = 'فشل تشغيل الخادم: $e');
    }
  }

  Future<void> stopServer() async {
    await server?.close(force: true);
    server = null;
    setState(() {
      url = '';
      status = 'تم إيقاف الخادم';
    });
  }

  @override
  void dispose() {
    server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PS4 Installer')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad, size: 70),
            const SizedBox(height: 20),
            Text(status, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: selectFile,
              child: const Text('اختيار ملف PKG'),
            ),
            ElevatedButton(
              onPressed: startServer,
              child: const Text('تشغيل الخادم'),
            ),
            ElevatedButton(
              onPressed: stopServer,
              child: const Text('إيقاف الخادم'),
            ),
            if (url.isNotEmpty)
              SelectableText(url),
          ],
        ),
      ),
    );
  }
}
