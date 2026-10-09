import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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
      title: 'PS4 Installer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController = TextEditingController();
  String _status = 'جاهز';
  bool _loading = false;

  Future<void> _pickAndSend() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pkg'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String ip = _ipController.text.trim();

        if (ip.isEmpty) {
          setState(() {
            _status = 'يرجى إدخال IP الخاص بالـ PS4';
          });
          return;
        }

        setState(() {
          _loading = true;
          _status = 'جاري إرسال الملف...';
        });

        var uri = Uri.parse('http://$ip:12800/api/install');
        var request = http.MultipartRequest('POST', uri)
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        var response = await request.send();

        if (response.statusCode == 200) {
          setState(() {
            _status = 'تم الإرسال بنجاح!';
          });
        } else {
          setState(() {
            _status = 'فشل الإرسال (رمز: ${response.statusCode})';
          });
        }
      } else {
        setState(() {
          _status = 'تم إلغاء اختيار الملف.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _loading = false;
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
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _pickAndSend,
              child: const Text('اختيار ملف وإرسال'),
            ),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(fontSize: 16, color: Colors.amber),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
