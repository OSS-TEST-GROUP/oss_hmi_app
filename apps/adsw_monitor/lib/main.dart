import 'package:flutter/material.dart';
import 'package:adsw_monitor/view/adsw_view_page.dart';
import 'package:adsw_monitor/view/mw_view_page.dart';

void main() {
  runApp(const AdswMonitorApp());
}

class AdswMonitorApp extends StatelessWidget {
  const AdswMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adsw Monitor App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const AdswMonitorHomePage(title: 'Adsw Monitor App Home'),
    );
  }
}

class AdswMonitorHomePage extends StatefulWidget {
  const AdswMonitorHomePage({super.key, required this.title});
  final String title;

  @override
  State<AdswMonitorHomePage> createState() => _AdswMonitorHomePageState();
}

class _AdswMonitorHomePageState extends State<AdswMonitorHomePage> with SingleTickerProviderStateMixin {
  
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 70,
            child: TabBar(
              controller: _tabController,
              overlayColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              tabs: const [
                Tab(text: 'AD SW Info'),
                Tab(text: 'Diagnostic Info'),
              ],
            ),
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