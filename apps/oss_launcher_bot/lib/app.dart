import 'package:flutter/material.dart';

import 'pages/launcher_bot_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OSS Launcher Bot',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF3E6AE1),
          secondary: Color(0xFF393C41),
          surface: Colors.white,
          onSurface: Color(0xFF171A20),
        ),
      ),
      home: const LauncherBotPage(),
    );
  }
}
