import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:adsw_monitor/config/config_loader.dart';
import 'package:adsw_monitor/config/app_config.dart';
import 'package:roslibdart/roslibdart.dart';
import 'ros_keeper.dart';

import 'package:adsw_monitor/view/adsw_view_page.dart';
import 'package:adsw_monitor/view/mw_view_page.dart';
import 'package:adsw_monitor/view/web_prompt_bootstrap.dart';
import 'package:adsw_monitor/view/log_overlay.dart';
import 'package:adsw_monitor/theme/adsw_palette.dart';

// L009: Export view widgets for launcher embedding
export 'view/adsw_view_page.dart' show AdswViewPage;
export 'view/mw_view_page.dart' show MwViewPage;

late AppConfig appConfig;
late RosKeeper rosKeeper;

typedef RosKeeperFactory = RosKeeper Function(AppConfig cfg);

Future<void> startRosWithUri(
  Uri rosUrl, {
  RosKeeperFactory? keeperFactory,
}) async {
  // 웹에서 입력 받은 URL로 AppConfig 구성
  appConfig = AppConfig(
    rosUrl: rosUrl,
    statusTopic: '/app_status/adsw_monitor',
  );

  // RosKeeper 생성 (테스트에서는 keeperFactory로 주입)
  final factory = keeperFactory ?? ((cfg) => RosKeeper(cfg));
  rosKeeper = factory(appConfig);

  // RosKeeper 시작
  await rosKeeper.start();

  // GetX 주입
  if (!Get.isRegistered<Ros>()) {
    Get.put<Ros>(rosKeeper.ros, permanent: true);
  } else {
    Get.replace<Ros>(rosKeeper.ros);
  }
}

void main(List<String> args) {
  //WidgetsFlutterBinding.ensureInitialized();

  runWithLogCapture(() async {
    if (kIsWeb) {
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: const WebPromptBootstrap(
            onConfigured: startRosWithUri,
            child: AdswMonitorApp(),
          ),
        ),
      );
    } else {
      appConfig = await loadConfig(args);
      rosKeeper = RosKeeper(appConfig);
      await rosKeeper.start();

      Get.put<Ros>(rosKeeper.ros, permanent: true);

      runApp(const AdswMonitorApp());
    }
  });
}

class AdswMonitorApp extends StatelessWidget {
  const AdswMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdswPalette>(
      valueListenable: adswPaletteNotifier,
      builder: (_, palette, __) => AdswPaletteScope(
        palette: palette,
        child: MaterialApp(
          title: 'Adsw Monitor App',
          theme: palette.toThemeData(),
          home: const AdswMonitorHomePage(title: 'Adsw Monitor App Home'),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class AdswMonitorHomePage extends StatefulWidget {
  const AdswMonitorHomePage({
    super.key,
    required this.title,
    this.adswPageBuilder,
    this.mwPageBuilder,
  });
  final String title;

  final Widget Function()? adswPageBuilder;
  final Widget Function()? mwPageBuilder;

  @override
  State<AdswMonitorHomePage> createState() => _AdswMonitorHomePageState();
}

class _AdswMonitorHomePageState extends State<AdswMonitorHomePage>
    with SingleTickerProviderStateMixin {
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

  void quitApp() {
    if (Platform.isLinux) {
      exit(0);
    } else if (Platform.isAndroid) {
      SystemNavigator.pop();
    }
  }

  Widget _buildHeader() {
    final palette = AdswPaletteScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
          decoration: BoxDecoration(
            color: palette.canvas,
            border: Border(bottom: BorderSide(color: palette.line, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // IconButton(
                  //   icon: Icon(Icons.arrow_back),
                  //   color: Colors.white,
                  //   iconSize: 30,
                  //   onPressed: () {
                  //     quitApp();
                  //   },
                  // ),
                  const SizedBox(width: 20),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: palette.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'AD SW Monitor',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
              Container(
                width: constraints.maxWidth * 0.4,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SizedBox(
                  height: 65,
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: palette.primaryText,
                    unselectedLabelColor: palette.muted,
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
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdswPaletteScope.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Logs',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const LogBottomSheet(),
          );
        },
        child: const Icon(Icons.terminal),
      ),
      body: Container(
        color: palette.canvas,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  widget.adswPageBuilder?.call() ?? const AdswViewPage(),
                  widget.mwPageBuilder?.call() ?? const MwViewPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
