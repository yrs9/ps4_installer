import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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
  final TextEditingController _ipController = TextEditingController(text: '192.168.0.131');
  bool _isSending = false;
  String _statusMessage = '';

  Future<void> _pickAndSendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pkg'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String ip = _ipController.text.trim();

      setState(() {
        _isSending = true;
        _statusMessage = 'جاري إرسال الملف...';
      });

      try {
        var uri = Uri.parse('http://$ip:12800/api/install');
        var request = http.MultipartRequest('POST', uri);
        
        // إضافة الملف مع ضبط الـ stream لتجنب انقطاع الاتصال Broken pipe
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );

        var streamedResponse = await request.send().timeout(
          const Duration(hours: 2), // مهلة زمنية طويلة للألعاب الكبيرة
          onTimeout: () {
            throw Exception('انتهت مهلة الاتصال (Timeout)');
          },
        );

        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          setState(() {
            _statusMessage = 'تم إرسال الملف بنجاح إلى PS4!';
          });
        } else {
          setState(() {
            _statusMessage = 'خطأ من البلايستيشن: ${response.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          _statusMessage = 'حدث خطأ: $e';
        });
      } finally {
        setState(() {
          _isSending = false;
        });
      }
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'PS4 IP Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _isSending
                const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _pickAndSendFile,
                    child: const Text('اختيار ملف وإرسال'),
                  ),
            const SizedBox(height: 20),
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
