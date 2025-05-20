import 'package:flutter/material.dart';

void main() {
  runApp(const OssHmiApp());
}

class OssHmiApp extends StatelessWidget {
  const OssHmiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oss Hmi App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const OssHomePage(title: 'Oss Hmi App Home'),
    );
  }
}

class OssHomePage extends StatefulWidget {
  const OssHomePage({super.key, required this.title});
  final String title;

  @override
  State<OssHomePage> createState() => _OssHomePageState();
}

class _OssHomePageState extends State<OssHomePage> {
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Tab
    );
  }
}
