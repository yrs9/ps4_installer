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
  HttpServer? _localServer;
  String? _selectedFilePath;
  String _statusMessage = 'السيرفر المحلي جاهز على البورت 8080';
  bool _isHosting = false;
  List<FileSystemEntity> _pkgFiles = [];

  @override
  void initState() {
    super.initState();
    _startLocalServer();
    _loadPkgFiles();
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

  void _loadPkgFiles() {
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (directory.existsSync()) {
        final list = directory.listSync(recursive: true);
        setState(() {
          _pkgFiles = list.where((entity) => entity.path.toLowerCase().endsWith('.pkg')).toList();
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في قراءة الملفات: $e';
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

  Future<void> _sendToPS4(String filePath) async {
    try {
      setState(() {
        _selectedFilePath = filePath;
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
          _statusMessage = 'تم الإرسال بنجاح! البلايستيشن يسحب اللعبة الآن...';
        });
      } else {
        setState(() {
          _statusMessage = 'خطأ من البلايستيشن: رمز الاستجابة ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ: $e';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPkgFiles,
            tooltip: 'تحديث القائمة',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
            const SizedBox(height: 15),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.amber),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ألعاب الـ PKG في مجلد Download:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _pkgFiles.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد ملفات PKG في مجلد Download\n(تأكد من وضع اللعبة هناك واضغط تحديث 🔄)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pkgFiles.length,
                      itemBuilder: (context, index) {
                        final file = _pkgFiles[index];
                        final fileName = file.path.split('/').last;
                        return Card(
                          color: Colors.grey[900],
                          child: ListTile(
                            title: Text(
                              fileName,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                              onPressed: _isHosting ? () => _sendToPS4(file.path) : null,
                              child: const Text('إرسال'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
