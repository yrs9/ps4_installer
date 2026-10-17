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
        status = 'تم اختيار: ${picked.name}';
      });
    } catch (e) {
      setState(() => status = 'خطأ في اختيار الملف: $e');
    }
  }

  Future<void> startServer() async {
    if (pkgFile == null) {
      setState(() => status = 'اختَر ملف PKG أولاً');
      return;
    }

    setState(() {
      busy = true;
      status = 'جارٍ تشغيل الخادم...';
    });

    try {
      await server?.close(force: true);

      final newServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        8080,
      );
      server = newServer;

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? ip;

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final value = address.address;
          if (value.startsWith('192.168.') ||
              value.startsWith('10.') ||
              value.startsWith('172.')) {
            ip = value;
            break;
          }
        }
        if (ip != null) break;
      }

      if (ip == null) {
        await newServer.close(force: true);
        server = null;
        setState(() => status = 'اتصل بالواي فاي وحاول مجدداً');
        return;
      }

      downloadUrl = 'http://$ip:8080/pkg';

      newServer.listen((request) async {
        if (request.method != 'GET' ||
            request.uri.path != '/pkg') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        try {
          final file = pkgFile;

          if (file == null || !await file.exists()) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }

          request.response.headers.contentType =
              ContentType('application', 'octet-stream');

          request.response.headers.set(
            'Content-Disposition',
            'attachment; filename="game.pkg"',
          );

          request.response.contentLength = await file.length();

          await request.response.addStream(file.openRead());
          await request.response.close();
        } catch (_) {
          try {
            request.response.statusCode =
                HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });

      setState(() => status = 'الخادم يعمل');
    } catch (e) {
      setState(() => status = 'فشل تشغيل الخادم: $e');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> stopServer() async {
    await server?.close(force: true);
    server = null;

    setState(() {
      downloadUrl = null;
      status = 'تم إيقاف الخادم';
    });
  }

  @override
  void dispose() {
    server?.close(force: true);
    super.dispose();
  }

  @override
