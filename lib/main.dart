import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تنظيف الكاش عند فتح التطبيق كإجراء احترازي
  await clearAppCache();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS4 PKG Installer',
      theme: ThemeData.dark(),
      home: const PS4InstallerHome(),
    );
  }
}

// دالة تنظيف الملفات المؤقتة لمنع تضخم المساحة
Future<void> clearAppCache() async {
  try {
    final tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      final List<FileSystemEntity> files = tempDir.listSync();
      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    }
  } catch (e) {
    debugPrint('خطأ أثناء تنظيف الكاش: $e');
  }
}

class PS4InstallerHome extends StatefulWidget {
  const PS4InstallerHome({super.key});

  @override
  State<PS4InstallerHome> createState() => _PS4InstallerHomeState();
}

class _PS4InstallerHomeState extends State<PS4InstallerHome> {
  final TextEditingController _ipController = TextEditingController();
  bool _isSending = false;
  String _statusMessage = 'جاهز لاختيار ملف الـ PKG';

  // دالة إرسال الملف المباشر دون عمل نسخة مؤقتة
  Future<void> sendPkgFile() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة عنوان IP الـ PS4')),
      );
      return;
    }

    // اختيار الملف مع تفعيل withReadStream لتجنب نسخه بداخل مجلد الكاش
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pkg'],
      withReadStream: true,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileSize = result.files.single.size;

      setState(() {
        _isSending = true;
        _statusMessage = 'جاري إرسال اللعبة إلى الـ PS4...';
      });

      try {
        final file = File(filePath);
        final uri = Uri.parse('http://$ip:12800/api'); // منفذ PS4 Package Installer
        
        var request = http.StreamedRequest('POST', uri);
        request.headers[HttpHeaders.contentLengthHeader] = fileSize.toString();

        // بث قراءة الملف مباشرة للشبكة
        file.openRead().listen(
          (chunk) => request.sink.add(chunk),
          onDone: () => request.sink.close(),
          onError: (e) => request.sink.close(),
          cancelOnError: true,
        );

        var response = await request.send();

        if (response.statusCode == 200) {
          setState(() {
            _statusMessage = 'تم إرسال اللعبة وتثبيتها بنجاح!';
          });
        } else {
          setState(() {
            _statusMessage = 'فشل الإرسال. كود الخطأ: ${response.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          _statusMessage = 'حدث خطأ بالاتصال: $e';
        });
      } finally {
        // تنظيف أي مخلفات مؤقتة فوراً بعد الانتهاء
        await clearAppCache();
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
        title: const Text('PS4 Installer'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عنوان IP الخاص بالـ PS4',
                hintText: '192.168.1.XX',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
