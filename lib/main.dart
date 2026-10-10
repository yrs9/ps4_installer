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
  final TextEditingController _ipController = TextEditingController(text: '10.16.250.133');
  bool _isSending = false;
  String _statusMessage = 'جاهز للاستخدام - اضغط للإرسال';

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        if (!file.path.toLowerCase().endsWith('.pkg')) {
          setState(() {
            _statusMessage = 'خطأ: يرجى اختيار ملف يحمل امتداد .pkg فقط';
          });
          return;
        }

        String ip = _ipController.text.trim();
        int totalSize = await file.length();

        setState(() {
          _isSending = true;
          _statusMessage = 'جاري النقل بأقصى سرعة...';
        });

        var uri = Uri.parse('http://$ip:12800/api/install');
        
        // استخدام StreamedRequest لنقل مباشر بدون تحميل الذاكرة
        var request = http.StreamedRequest('POST', uri);
        request.headers['content-type'] = 'application/octet-stream';
        request.contentLength = totalSize;

        // فتح الملف وقراءته بسرعة عالية وإرساله للـ Sink دفعة دفعة
        var fileStream = file.openRead();
        
        // ربط البث بشكل مباشر وسريع جداً
        request.sink.addStream(fileStream).then((_) {
          request.sink.close();
        }).catchError((err) {
          request.sink.addError(err);
        });

        var streamedResponse = await request.send().timeout(
          const Duration(hours: 3),
          onTimeout: () {
            throw Exception('انتهت مهلة الاتصال');
          },
        );

        if (streamedResponse.statusCode == 200) {
          setState(() {
            _statusMessage = 'تم إرسال اللعبة بنجاح إلى PS4!';
          });
        } else {
          setState(() {
            _statusMessage = 'خطأ من البلايستيشن: ${streamedResponse.statusCode}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في النقل: تأكد من الاتصال وسرعة الشبكة';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 25),
            _isSending
                ? Column(
                    children: const [
                      CircularProgressIndicator(color: primaryColor),
                      SizedBox(height: 15),
                      Text(
                        'جاري نقل البيانات بأقصى سرعة للـ PS4...\nيرجى الانتظار...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.blueAccent),
                      ),
                    ],
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _pickAndSendFile,
                    child: const Text(
                      'اختيار ملف وإرسال',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 25),
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
