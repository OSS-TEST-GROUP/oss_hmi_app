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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF64748B),
        ),
      ),
      home: const AdswMonitorHomePage(title: 'Adsw Monitor App Home'),
      debugShowCheckedModeBanner: false,
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

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.8),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF374151), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Color(0xFF60A5FA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AD SW Monitor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Container(
              width: constraints.maxWidth * 0.4,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF374151), width: 0.5),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color.fromARGB(255, 51, 109, 201),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF9CA3AF),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'AD SW Info'),
                  Tab(text: 'Diagnostic Info'),
                ],
              ),
            ),
          ],
        ),
      );

      }
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  AdswViewPage(),
                  MwViewPage(),
                ],
              ),
            ),
          ],),
      ),
    );

    
    
    // return Scaffold(
    //   backgroundColor: Colors.white,
    //   body: Column(
    //     children: [
    //       SizedBox(
    //         height: 70,
    //         child: TabBar(
    //           controller: _tabController,
    //           overlayColor: const WidgetStatePropertyAll(
    //             Colors.transparent,
    //           ),
    //           tabs: const [
    //             Tab(text: 'AD SW Info'),
    //             Tab(text: 'Diagnostic Info'),
    //           ],
    //         ),
    //       ),
    //       Expanded(
    //         child: TabBarView(
    //           controller: _tabController,
    //           children: const [
    //             AdswViewPage(),
    //             MwViewPage(),
    //           ],
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}