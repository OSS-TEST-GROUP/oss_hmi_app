import 'package:flutter/material.dart';
import 'package:oss_hmi_app/views/adsw_view_page.dart';
import 'package:oss_hmi_app/views/mw_view_page.dart';

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

class _OssHomePageState extends State<OssHomePage> with SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'AD SW Info'),
              Tab(text: 'Diagnostic Info'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AdswViewPage(),
                MwViewPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
