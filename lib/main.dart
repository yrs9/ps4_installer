import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PS4 PKG Sender',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const InstallerPage(),
      );
}

class InstallerPage extends StatefulWidget {
  const InstallerPage({super.key});

  @override
  State<InstallerPage> createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage> {
  static const int _port = 8080;
  HttpServer? _server;
  File? _selectedFile;
  String _status = 'اختَر ملف PKG للبدء';
  String _url = '';
  bool _busy = false;

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<String?> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              RegExp(r'^172\.(1[6-9]|2[0-9]|3[01])\.').hasMatch(ip)) {
            return ip;
          }
        }
      }
    } on SocketException {
      // Wi-Fi may not be connected yet.
    }
    return null;
  }

  Future<void> _pickAndShare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'جاري اختيار ملف PKG...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pkg'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _status = 'تم إلغاء الاختيار');
        return;
      }

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        throw FileSystemException('تعذّر الوصول إلى مسار الملف');
      }
      final file = File(path);
      if (!await file.exists()) {
        throw FileSystemException('الملف غير موجود');
      }

      await _server?.close(force: true);
      final server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      server.listen((request) => _handleRequest(request, file));
      final ip = await _findLocalIp();
      if (ip == null) {
        await server.close(force: true);
        throw SocketException('اتصل بشبكة Wi-Fi ثم حاول مجدداً');
      }

      if (!mounted) {
        await server.close(force: true);
        return;
      }
      setState(() {
        _server = server;
        _selectedFile = file;
        _url = 'http://$ip:$_port/pkg';
        _status = 'الخادم يعمل — تأكد أن الهاتف وPS4 على نفس الشبكة';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'خطأ: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRequest(HttpRequest request, File file) async {
    try {
      if (request.uri.path != '/pkg' ||
          (request.method != 'GET' && request.method != 'HEAD')) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
        return;
      }

      final length = await file.length();
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      var start = 0;
      var end = length - 1;
      var partial = false;

      if (rangeHeader != null && length > 0) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(rangeHeader);
        if (match == null || (match.group(1)!.isEmpty && match.group(2)!.isEmpty)) {
          request.response
            ..statusCode = HttpStatus.requestedRangeNotSatisfiable
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
          await request.response.close();
          return;
        }
        if (match.group(1)!.isEmpty) {
          final suffix = int.tryParse(match.group(2)!);
          if (suffix == null || suffix <= 0) {
            request.response
              ..statusCode = HttpStatus.requestedRangeNotSatisfiable
              ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
            await request.response.close();
            return;
          }
          start = (length - suffix).clamp(0, length).toInt();
        } else {
          start = int.parse(match.group(1)!);
          if (match.group(2)!.isNotEmpty) end = int.parse(match.group(2)!);
        }
        if (start >= length || end < start) {
          request.response
            ..statusCode = HttpStatus.requestedRangeNotSatisfiable
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
          await request.response.close();
          return;
        }
        end = end.clamp(0, length - 1).toInt();
        partial = true;
      }

      final response = request.response;
      response.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
        ..set(HttpHeaders.contentDispositionHeader, 'attachment; filename="${file.uri.pathSegments.last}"')
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentLengthHeader, partial ? end - start + 1 : length)
        ..set(HttpHeaders.cacheControlHeader, 'no-store');
      if (partial) {
        response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length');
      } else {
        response.statusCode = HttpStatus.ok;
      }

      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      await response.addStream(file.openRead(start, end + 1));
      await response.close();
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الرابط')),
      );
    }
  }

  Future<void> _stopServer() async {
    await _server?.close(force: true);
    if (mounted) {
      setState(() {
        _server = null;
        _url = '';
        _selectedFile = null;
        _status = 'تم إيقاف الخادم';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _selectedFile?.uri.pathSegments.last;
    return Scaffold(
      appBar: AppBar(title: const Text('PS4 PKG Sender')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sports_esports, size: 72),
                  const SizedBox(height: 16),
                  Text(_status, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickAndShare,
                    icon: const Icon(Icons.folder_open),
                    label: Text(_busy ? 'انتظر...' : 'اختيار ملف PKG'),
                  ),
                  if (fileName != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الملف المختار', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            SelectableText(fileName),
                            const SizedBox(height: 6),
                            Text('${(_selectedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('رابط الملف على الشبكة:', textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    SelectableText(_url, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _url.isEmpty ? null : _copyUrl,
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ الرابط'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _server == null ? null : _stopServer,
                      icon: const Icon(Icons.stop),
                      label: const Text('إيقاف الخادم'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'ملاحظة: هذا التطبيق يوفّر رابط تحميل للملف فقط. تثبيت PKG على PS4 يحتاج أداة استقبال متوافقة على جهة البلايستيشن.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
