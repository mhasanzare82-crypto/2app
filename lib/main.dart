import 'package:flutter/material.dart';

import 'screens/apk_import_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TwoApp());
}

class TwoApp extends StatelessWidget {
  const TwoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '2app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315C9B)),
        useMaterial3: true,
      ),
      home: const ApkImportPage(),
    );
  }
}
