import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
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
      title: 'PS4 Remote Installer',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String _status = 'جاهز للاستخدام';
  HttpServer? _server;
  String _hostedFileUrl = '';
  final TextEditingController _ipController = TextEditingController();

  @override
  void dispose() {
    _server?.close();
    _ipController.dispose();
    super.dispose();
  }

  Future<String> _getLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4)) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.') || addr.address.startsWith('10.') || addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> _startServerAndPickFile() async {
    try {
      setState(() {
        _status = 'جاري اختيار الملف...';
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        File file = File(filePath);

        if (_server != null) {
          await _server!.close();
