import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() {
  runApp(const Ps4InstallerApp());
}

class Ps4InstallerApp extends StatelessWidget {
  const Ps4InstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS4 Remote Installer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const InstallerHomePage(),
    );
  }
}

class InstallerHomePage extends StatefulWidget {
  const InstallerHomePage({super.key});

  @override
  State<InstallerHomePage> createState() => _InstallerHomePageState();
}

class _InstallerHomePageState extends State<InstallerHomePage> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.');
  String _statusMessage = 'جاهز للاستخدام';
  bool _isUploading = false;

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pkg'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String ps4Ip = _ipController.text.trim();

        if (ps4Ip.isEmpty) {
          setState(() {
            _statusMessage = 'الرجاء إدخال عنوان IP الخاص بالـ PS4';
          });
          return;
        }

        setState(() {
          _isUploading = true;
          _statusMessage = 'جاري إرسال اللعبة إلى PS4...';
        });

        var uri = Uri.parse('http://$ps4Ip:12800/api/install');
        var request = http.MultipartRequest('POST', uri)
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        var response = await request.send();

        if (response.statusCode == 200) {
          setState(() {
            _statusMessage = 'تم إرسال اللعبة بنجاح إلى PS4!';
          });
        } else {
          setState(() {
            _statusMessage = 'فشل الإرسال، تأكد من فتح برنامج التثبيت على PS4 (كود: ${response.statusCode})';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'تم إلغاء اختيار الملف.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PS4 Remote Installer'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'PS4 IP Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.network_check),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndSendFile,
              icon: const Icon(Icons.folder_open),
              label: const Text(
                'اختر ملف PKG وأرسله',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 30),
          if (_isUploading) const CircularProgressIndicator(),
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
