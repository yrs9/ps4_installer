import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const PS4App());
}

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
  String status = 'اختر ملف PKG';
  String? downloadUrl;
  bool busy = false;

  Future<void> choosePkg() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pkg'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      pkgFile = File(result.files.single.path!);
      status = 'تم اختيار ${result.files.single.name}';
    });
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

      server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        8080,
      );

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
        await server?.close(force: true);
        server = null;
        setState(() => status = 'اتصل بالواي فاي وحاول مجدداً');
        return;
      }

      downloadUrl = 'http://$ip:8080/pkg';
      final activeServer = server!;

      activeServer.listen((request) async {
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
          request.response.headers.contentLength =
              await file.length();

          await request.response.addStream(file.openRead());
          await request.response.close();
        } catch (_) {
          if (!request.response.headersSent) {
            request.response.statusCode =
                HttpStatus.internalServerError;
          }
          await request.response.close();
        }
      });

      setState(() => status = 'الخادم يعمل');
    } catch (e) {
      setState(() => status = 'خطأ: $e');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PS4 Installer')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_esports, size: 80),
              const SizedBox(height: 20),
              Text(status, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : choosePkg,
                  child: const Text('اختيار ملف PKG'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : startServer,
                  child: const Text('تشغيل الخادم'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: stopServer,
                  child: const Text('إيقاف الخادم'),
                ),
              ),
              if (downloadUrl != null) ...[
                const SizedBox(height: 20),
                SelectableText(
                  downloadUrl!,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
