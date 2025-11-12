import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:adsw_monitor/config/config_loader.dart';
import 'package:adsw_monitor/config/app_config.dart';
import 'package:roslibdart/roslibdart.dart';
import 'ros_keeper.dart';

import 'package:adsw_monitor/view/adsw_view_page.dart';
import 'package:adsw_monitor/view/mw_view_page.dart';
import 'package:adsw_monitor/view/web_prompt_bootstrap.dart';

late AppConfig appConfig;
late RosKeeper rosKeeper;

Future<void> _startRosWithUri(Uri rosUrl) async {
  // 웹에서 입력 받은 URL로 AppConfig 구성
  appConfig = AppConfig(rosUrl: rosUrl, statusTopic: '/app_status/adsw_monitor');

  // RosKeeper 시작
  rosKeeper = RosKeeper(appConfig);
  await rosKeeper.start();

  // GetX 주입
  if (!Get.isRegistered<Ros>()) {
    Get.put<Ros>(rosKeeper.ros, permanent: true);
  } else {
    Get.replace<Ros>(rosKeeper.ros);
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

   if (kIsWeb) {
    // 웹: 부트스트랩으로 주소 입력 → 연결 후 메인 앱 표시
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: WebPromptBootstrap(
        onConfigured: _startRosWithUri,
        child: const AdswMonitorApp(), // 기존 앱 그대로
      ),
    ));
  } else {
    // IO: 기존 흐름 그대로
    appConfig = await loadConfig(args);
    rosKeeper = RosKeeper(appConfig);
    await rosKeeper.start();

    Get.put<Ros>(rosKeeper.ros, permanent: true);

    runApp(AdswMonitorApp());
  }
}

class AdswMonitorApp extends StatelessWidget {
  const AdswMonitorApp({super.key,});

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
      home: AdswMonitorHomePage(title: 'Adsw Monitor App Home',),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdswMonitorHomePage extends StatefulWidget {
  const AdswMonitorHomePage({super.key, required this.title,});
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
    rosKeeper.stop();
    super.dispose();
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Color(0xFF60A5FA),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 20),
                const Text(
                  'AD SW Monitor',
                  style: TextStyle(
                    fontSize: 30,
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
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF374151), width: 0.5),
              ),
              child: SizedBox(
                height: 65,
                child: TabBar(
                  dividerColor: Colors.transparent,
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color.fromARGB(255, 51, 109, 201),
                    borderRadius: BorderRadius.circular(10),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'AD SW Info'),
                    Tab(text: 'Diagnostic Info'),
                  ],
                ),
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
  }
}
