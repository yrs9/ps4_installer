import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
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
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // طلب إذن الوصول إلى الملفات عند فتح التطبيق
  Future<void> _requestPermissions() async {
    var status = await Permission.storage.request();
    var manageStatus = await Permission.manageExternalStorage.request();
    
    if (status.isGranted || manageStatus.isGranted) {
      setState(() {
        _statusMessage = 'تم منح إذن الوصول للملفات بنجاح';
      });
    } else {
      setState(() {
        _statusMessage = 'يرجى السماح بالوصول للملفات من إعدادات الهاتف لاختيار الألعاب';
      });
    }
  }

  // اختيار ملف الـ PKG وإرساله إلى الـ PS4
  Future<void> _pickAndSendFile() async {
    try {
      // التأكد من الأذونات قبل فتح مدير الملفات
      if (await Permission.storage.isDenied && await Permission.manageExternalStorage.isDenied) {
        await _requestPermissions();
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pkg'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String ps4Ip = _ipController.text.trim();

        if (ps4Ip.isEmpty) {
          setState(() {
            _statusMessage = 'الرجاء إدخال عنوان IP الخاص بالـ PS4 بشكل صحيح';
          });
          return;
        }

        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
          _statusMessage = 'جاري تحضير ملف اللعبة للإرسال...';
        });

        var uri = Uri.parse('http://$ps4Ip:12800/api/install');
        var request = http.MultipartRequest('POST', uri);
        
        var multipartFile = await http.MultipartFile.fromPath('file', file.path);
        request.files.add(multipartFile);

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          setState(() {
            _statusMessage = 'تم إرسال اللعبة بنجاح إلى الـ PS4 وبدأ التثبيت!';
          });
        } else {
          setState(() {
            _statusMessage = 'فشل الإرسال، تأكد من فتح تطبيق التثبيت على الـ PS4 (كود الخطأ: ${response.statusCode})';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'تم إلغاء اختيار الملف.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء الإرسال: $e';
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
            const Icon(Icons.sports_esports, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'عنوان IP الخاص بالـ PS4',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndSendFile,
                icon: const Icon(Icons.folder_open),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text(
                  'اختر ملف PKG وأرسله للـ PS4',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_isUploading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 15),
            ],
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
