import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../config/config_loader.dart';
import '../config/docker_args_format.dart';
import '../config/user_config_store.dart';
import '../controller/rviz2_controller.dart';
import '../data/rviz2_data.dart';

/// Single-screen view for rviz2_panel (direct-docker variant).
///
/// Layout (wide ≥900px):
///   ┌─────────────────────────────┬─────────────────────────┐
///   │ Status card + Options form  │   docker logs view      │
///   └─────────────────────────────┴─────────────────────────┘
/// Narrow: panels stack vertically.
///
/// Exported from main.dart so the hmi_launcher embedded panel can reference
/// it without importing internal sub-paths directly.
class Rviz2ViewPage extends StatefulWidget {
  const Rviz2ViewPage({
    super.key,
    required this.cfg,
    this.embedded = false,
    this.userConfigStore,
  });

  final AppConfig cfg;

  /// 설정 저장소 주입점 — 테스트에서 임시 디렉토리를 가리키게 하기 위해 둔다.
  /// null 이면 실제 경로($XDG_CONFIG_HOME/rviz2_panel)를 쓴다.
  final UserConfigStore? userConfigStore;

  /// True when hosted inside hmi_launcher. Controls minor layout tweaks
  /// (e.g. no window-level title bar in standalone mode).
  final bool embedded;

  @override
  State<Rviz2ViewPage> createState() => _Rviz2ViewPageState();
}

/// Baked-in Autoware rviz layout inside the `:autoware` image (from the
/// junohb autoware overlay). Referenced by the "Autoware (151)" preset and
/// passed to rviz2 as `-e RVIZ_CONFIG=<path>` (→ `rviz2 -d <path>`).
const String kAutowareRvizConfig =
    '/opt/autoware/share/autoware_launch/rviz/autoware.rviz';

/// ROS 2 domain the adsw-managed Autoware partitions run on (151,
/// saved-service-list.yaml). If Autoware runs as `oss-mmf-ext-ros2` instead,
/// use domain 0 — edit the field after applying the preset.
/// Autoware(151) 프리셋의 도메인 — "Autoware (151) preset" 버튼이 되돌릴 값.
/// 초기 프리필은 [AppConfig.defaultDomainId] (런처 Settings 의 DDS domain) 를 쓴다.
const String kAutowareDomainId = '42';

/// RMW Autoware uses by default (Humble default = FastDDS). Must match on both
/// boards, otherwise cross-board DDS discovery fails outright (no topics at all).
const String kAutowareRmw = 'rmw_fastrtps_cpp';

/// 이미지에 **실제로 설치된** RMW 구현 목록 (실측: /opt/ros/humble/lib 의
/// librmw_fastrtps_cpp.so, librmw_cyclonedds_cpp.so). 필드 우측 ▾ 메뉴로 노출해
/// "무엇을 넣을 수 있는지" 를 화면에서 알 수 있게 한다 — 오타 방지 + 탐색 불필요.
/// 값은 자유 입력도 가능하다(이미지에 다른 RMW 를 추가한 경우).
const List<(String value, String label)> kRmwChoices = [
  ('', '(비움) — 이미지 기본값: FastDDS'),
  ('rmw_fastrtps_cpp', 'rmw_fastrtps_cpp — FastDDS (Autoware 기본)'),
  ('rmw_cyclonedds_cpp', 'rmw_cyclonedds_cpp — Cyclone DDS'),
];

class _Rviz2ViewPageState extends State<Rviz2ViewPage> {
  /// 이 패널이 화면에서 차지하는 사각형을 재기 위한 키. 'View rviz2' 는 이 사각형에
  /// rviz2 를 띄운다 — 런처 사이드바·타이틀이 살아 있어야 앱 전환이 가능하기 때문.
  final GlobalKey _bodyKey = GlobalKey();
  late final Rviz2Controller _ctrl;

  // Options form — pre-filled with the Autoware-on-151 defaults so a plain
  // "Start" connects to Autoware out of the box (domain 42 / FastDDS /
  // autoware.rviz). Users can edit these (e.g. domain 0 for oss-mmf-ext-ros2)
  // or clear them; the "Autoware (151) preset" button re-applies them.
  final TextEditingController _rvizConfigCtrl =
      TextEditingController(text: kAutowareRvizConfig);
  // 도메인 프리필은 cfg(=런처 Settings 의 DDS domain) 에서 온다 — widget 접근이
  // 필요하므로 initState 에서 초기화한다.
  late final TextEditingController _domainIdCtrl;
  final TextEditingController _rmwCtrl =
      TextEditingController(text: kAutowareRmw);

  // ── 패널 설정(영구 저장) 폼 ──────────────────────────────────────────────
  // 아래 필드들은 "저장" 버튼으로, Run Options 세 값은 **Start 를 누를 때**
  // 같은 파일에 기록된다($XDG_CONFIG_HOME/rviz2_panel/config.json) — 저장 시점만
  // 다르고 목적지는 하나다. 근거는 _persistRunOptions 주석 참조.
  late final TextEditingController _imageCtrl;
  late final TextEditingController _containerCtrl;
  late final TextEditingController _outputCtrl;
  late final TextEditingController _rvizAppIdCtrl;
  late final TextEditingController _homeAppIdCtrl;
  late final TextEditingController _pollCtrl;
  late final TextEditingController _dockerArgsCtrl;
  late final UserConfigStore _userCfg = widget.userConfigStore ?? UserConfigStore();
  bool _savingCfg = false;
  String? _cfgMsg;

  // Log auto-scroll.
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    // 런처 Settings 의 DDS domain 이 cfg 로 내려온다(단독 실행 시 kFallbackDomainId).
    _domainIdCtrl = TextEditingController(text: widget.cfg.defaultDomainId);

    // 저장된 값이 있으면 Run Options 도 그것으로 시작한다(없으면 Autoware 프리셋).
    if (widget.cfg.rvizConfigPath.isNotEmpty) {
      _rvizConfigCtrl.text = widget.cfg.rvizConfigPath;
    }
    if (widget.cfg.rmwImplementation.isNotEmpty) {
      _rmwCtrl.text = widget.cfg.rmwImplementation;
    }

    _imageCtrl = TextEditingController(text: widget.cfg.image);
    _containerCtrl = TextEditingController(text: widget.cfg.containerName);
    _outputCtrl = TextEditingController(text: widget.cfg.aglOutput);
    _rvizAppIdCtrl = TextEditingController(text: widget.cfg.rvizAppId);
    _homeAppIdCtrl = TextEditingController(text: widget.cfg.homeAppId);
    _pollCtrl =
        TextEditingController(text: '${widget.cfg.pollIntervalSec}');
    _dockerArgsCtrl =
        TextEditingController(text: dockerArgsToText(widget.cfg.dockerRunArgs));

    _ctrl = Get.isRegistered<Rviz2Controller>()
        ? Get.find<Rviz2Controller>()
        : Get.put(
            Rviz2Controller(cfg: widget.cfg),
            permanent: true,
          );

    // Auto-scroll log list to newest line on each update.
    _ctrl.logs.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollCtrl.hasClients) {
          _logScrollCtrl.animateTo(
            _logScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    // 런처에서 **다른 앱으로 전환**하면 이 패널이 dispose 된다. rviz2 는 런처 위에 떠
    // 있으므로 여기서 내리지 않으면 새로 고른 앱 화면이 rviz2 뒤에 가린다(보드 실측).
    // 컨테이너는 그대로 두므로 rviz2 아이콘으로 돌아와 'View rviz2' 를 누르면 다시 뜬다.
    if (widget.embedded) unawaited(_ctrl.hideRviz2());
    _rvizConfigCtrl.dispose();
    _domainIdCtrl.dispose();
    _rmwCtrl.dispose();
    _imageCtrl.dispose();
    _containerCtrl.dispose();
    _outputCtrl.dispose();
    _rvizAppIdCtrl.dispose();
    _homeAppIdCtrl.dispose();
    _pollCtrl.dispose();
    _dockerArgsCtrl.dispose();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  /// 상단(제어+옵션) 영역 높이 — 핸들 드래그로 조절한다. 로그는 남은 공간을 모두 쓴다.
  /// null 이면 **내용 높이에 맞춰 자동**(카드 두 장이 나란히 = 약 200px). 사용자가 핸들을
  /// 끌면 그 값이 들어가 고정된다. 더블클릭으로 자동으로 되돌린다.
  /// (고정 기본값 300 을 쓰면 카드가 200 인 경우 100px 빈 공간이 남았다 — 실측)
  /// 좌(제어·옵션·설정) : 우(docker logs) 폭 비율. null 이면 기본값 [_kLeftDefault].
  /// 가로 화면에서 가운데 핸들을 끌어 조절한다(더블탭 = 기본값 복귀).
  double? _leftFraction;
  static const double _kLeftDefault = 0.75; // 3 : 1
  static const double _kLeftMin = 0.35;
  static const double _kLeftMax = 0.85;

  /// 상단/로그 경계의 드래그 핸들. 위로 끌면 로그가 커지고 아래로 끌면 상단이 커진다.
  /// 좌우 폭 조절 핸들. 끌면 [_leftFraction] 을 바꾸고, 더블탭하면 기본 3:1 로 되돌린다.
  /// (예전에는 상하 높이 조절 핸들이었다 — 로그가 아래 전체 폭을 차지하던 레이아웃)
  Widget _buildSideResizeHandle(BuildContext context, double usable) {
    final outline = Theme.of(context).colorScheme.outline;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => setState(() {
          if (usable <= 0) return;
          _leftFraction =
              ((_leftFraction ?? _kLeftDefault) + d.delta.dx / usable)
                  .clamp(_kLeftMin, _kLeftMax);
        }),
        onDoubleTap: () => setState(() => _leftFraction = null),
        child: Tooltip(
          message: '드래그로 좌우 폭 조절 (더블탭 = 기본 3:1)',
          child: SizedBox(
            width: 18,
            child: Center(
              child: Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: outline.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Row(
                children: [
                  Text('RViz2 Monitor',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
      body: Container(
        key: _bodyKey,
        child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          // 좁은 화면(세로 배치)에서만 쓰는 묶음 — wide 경로는 카드를 직접 배치한다.
          final leftPanel = _buildLeftPanel(context);
          final rightPanel = _buildLogPanel(context);
          const gap = SizedBox(width: 12, height: 12);

          if (wide) {
            // 좌: RViz2 Control + Run Options + 패널 설정 / 우: docker logs.
            // 가운데 핸들을 끌어 **좌우 폭 비율**을 조절한다(기본 3:1, 더블탭 복귀).
            // 좌측은 카드가 길어 세로 스크롤을 두고, 로그가 남은 폭을 채운다.
            const handleW = 18.0;
            final frac =
                (_leftFraction ?? _kLeftDefault).clamp(_kLeftMin, _kLeftMax);
            final usable =
                (c.maxWidth - 24 - handleW).clamp(0.0, double.infinity);

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: usable * frac,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(child: leftPanel),
                        ),
                        _buildErrorBanner(context),
                      ],
                    ),
                  ),
                  _buildSideResizeHandle(context, usable),
                  Expanded(child: rightPanel),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                leftPanel,
                gap,
                SizedBox(height: 360, child: rightPanel),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  /// 'View rviz2' — **이 패널이 지금 차지한 사각형**에 rviz2 를 띄운다.
  ///
  /// 전체 화면으로 덮지 않는 이유: 런처 사이드바·타이틀이 남아 있어야 아이콘 탭으로
  /// 다른 앱으로 전환할 수 있다(rviz2 밖의 터치는 런처가 받는다 — 보드 실측).
  /// 사각형을 못 재면(단독 실행 등) 종전대로 전체 화면.
  void _onViewRviz2() => _ctrl.showRviz2(rect: _panelRect());

  /// 이 패널이 화면에서 차지한 사각형(물리 픽셀). 단독 실행이거나 아직 레이아웃 전이면 null.
  ///
  /// agl-shell 은 **물리 픽셀**로 기하를 받는다. Flutter 좌표는 논리 픽셀이므로
  /// devicePixelRatio 로 환산한다(보드는 1.0 이지만 스케일 화면 대비).
  Rect? _panelRect() {
    final box = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (!widget.embedded || box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Rect.fromLTWH(origin.dx * dpr, origin.dy * dpr,
        box.size.width * dpr, box.size.height * dpr);
  }

  // ─── Left panel: status + control + options ───────────────────────────────

  Widget _buildLeftPanel(BuildContext context) {
    // 카드 → (남는 공간) → 에러 배너.
    // 에러 배너를 카드 안이 아니라 **열의 맨 아래**에 두는 이유: 카드 안에 있으면 배너가
    // 뜰 때 아래 요소가 밀려 Start/Stop 버튼 위치가 바뀐다(실측: 20px). 터치 화면에서
    // 목표가 움직이는 것은 오조작으로 이어지므로, 버튼 위쪽 레이아웃은 상태와 무관하게
    // 고정하고 가변 요소는 모두 아래로 몬다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(context),
        const SizedBox(height: 12),
        // ⚠️ Expanded/Spacer 를 쓰지 않는다 — 이 묶음은 ListView(좁은 화면)와
        //    SingleChildScrollView(넓은 화면) 안에 들어가 높이가 무한이다.
        //    스크롤과 에러 배너 배치는 호출부가 맡는다.
        _buildSettingsCard(context),
        const SizedBox(height: 12),
        _buildOptionsCard(context),
      ],
    );
  }

  /// 카드 밖(열 맨 아래)에 놓이는 에러 배너 — 표시/숨김이 버튼 위치에 영향을 주지 않는다.
  Widget _buildErrorBanner(BuildContext context) {
    return Obx(() {
      final err = _ctrl.lastError.value;
      if (err == null) return const SizedBox.shrink();
      // 배경은 **투명**으로 둔다 — errorContainer(연빨강) 바탕 + redAccent 글씨는 대비가
      // 낮아 읽기 어려웠다(실측). 카드/서피스 색을 그대로 두고 왼쪽 빨강 막대 + 진한 빨강
      // 글씨로 구분한다. 글씨색은 Stop 버튼·로그 ERR 레벨과 같은 red.shade700 로 통일.
      final errColor = Colors.red.shade700;
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(left: BorderSide(color: errColor, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 16, color: errColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(err,
                  style: TextStyle(fontSize: 12, color: errColor),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              tooltip: 'Dismiss',
              onPressed: () => _ctrl.lastError.value = null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatusCard(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더: 제목 + 상태 새로고침 (아이콘을 헤더로 올려 DISPLAY 행을 비운다)
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('RViz2 Control',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh status',
                  onPressed: _ctrl.refreshStatus,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── 상태 스트립: **높이 고정**. 배지/exit/변경시각/힌트가 있든 없든 같은 높이.
            SizedBox(
              height: 52,
              child: Obx(() {
                final info = _ctrl.container.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ContainerStateRow(info: info),
                    const SizedBox(height: 4),
                    Text(_stateHint(info.state),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: outline)),
                  ],
                );
              }),
            ),
            const Divider(height: 20),
            // ── 액션 한 줄: 실행 제어(Start/Stop) | 표시 전환(View rviz2)
            //    두 그룹을 한 행에 모아 세로 길이를 줄이고, 높이를 고정해 좌표를 안정화.
            SizedBox(
              height: 40,
              child: Obx(() {
                final state = _ctrl.container.value.state;
                final canStart = state == ContainerState.notInstalled ||
                    state == ContainerState.exited ||
                    state == ContainerState.created;
                final isRunning = state == ContainerState.running;
                return Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: canStart ? _onStart : null,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: isRunning ? _ctrl.stop : null,
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: isRunning
                          ? 'Show rviz2 fullscreen'
                          : 'Start rviz2 first',
                      child: OutlinedButton.icon(
                        onPressed: isRunning ? _onViewRviz2 : null,
                        icon: const Icon(Icons.view_in_ar, size: 18),
                        label: const Text('View rviz2'),
                      ),
                    ),
                    // 'Launcher'(홈 복귀) 버튼은 제거했다 — 이 버튼은 **런처 화면에서만**
                    // 누를 수 있는데, 그때는 이미 런처가 앞에 있어 할 일이 없다. rviz2 가
                    // 앞에 있을 때의 홈 복귀는 rviz2 위에 떠 있는 homebar(우상단)가 맡는다.
                  ],
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Start → View rviz2 → Home 버튼으로 런처 복귀',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: outline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Options form: local state. Each non-empty field is injected as a
  /// `-e KEY=VALUE` on the next `docker run` (see [_onStart]):
  ///   [_rvizConfigCtrl] → `RVIZ_CONFIG` (entrypoint runs `rviz2 -d <path>`),
  ///   [_domainIdCtrl]   → `ROS_DOMAIN_ID`,
  ///   [_rmwCtrl]        → `RMW_IMPLEMENTATION`.
  /// The "Autoware (151) preset" fills all three for Autoware visualization.
  Widget _buildOptionsCard(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더에 프리셋 버튼을 함께 둔다 — 별도 행을 없애 카드 높이를 줄인다.
            Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                const Text('Run Options',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('(optional)',
                    style: TextStyle(fontSize: 11, color: outline)),
                const Spacer(),
                // 이전에는 라벨이 "Autoware (151)" 인 OutlinedButton 이었다. 값을 **표시**하는
                // 배지처럼 보여 무엇이 일어나는지 모른 채 누르게 됐다(사용자 지적).
                // 동작이 드러나는 라벨의 텍스트 버튼으로 바꾸고, 어떤 프리셋인지는 아래
                // 설명문에 **텍스트**로 적는다(누를 수 있는 요소로 오인되지 않도록).
                Tooltip(
                  message: '아래 세 값을 Autoware(151) 기준으로 채운다 '
                      '(ROS_DOMAIN_ID $kAutowareDomainId · $kAutowareRmw · autoware.rviz)',
                  child: TextButton.icon(
                    onPressed: _applyAutowarePreset,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('기본값 채우기'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Start 를 누르면 적용되고 **저장**됩니다 — 앱을 다시 띄워도 이 값이 '
              '유지됩니다. 저장된 ROS_DOMAIN_ID 는 런처 Settings 값으로 덮이지 '
              '않습니다(되돌리려면 아래 "기기 기본값으로"). 프리셋 기준값 — '
              'ROS_DOMAIN_ID $kAutowareDomainId · $kAutowareRmw · autoware.rviz',
              style: TextStyle(fontSize: 11, color: outline),
            ),
            const SizedBox(height: 14),
            // .rviz 레이아웃 — -e RVIZ_CONFIG=<path> → `rviz2 -d <path>`
            // 긴 설명은 Tooltip 으로 옮겨 카드 높이를 줄인다(helper 는 한 줄).
            Tooltip(
              message: '이미지 안의 레이아웃 경로. 비우면 rviz2 기본 뷰.\n'
                  'Autoware: $kAutowareRvizConfig',
              child: TextField(
                controller: _rvizConfigCtrl,
                decoration: const InputDecoration(
                  labelText: 'RViz config (in-container path)',
                  hintText: kAutowareRvizConfig,
                  helperText: '비우면 기본 뷰',
                  prefixIcon: Icon(Icons.folder_open, size: 18),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            // 짧은 두 값은 한 행에 — 세로 3칸을 2칸으로 줄인다.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: 'Autoware 와 같아야 한다 — 두 쪽이 다르면 맵/토픽이 '
                        '전혀 보이지 않는다.\n'
                        'Start 시 저장되어 앱 재시작 후에도 유지된다.\n'
                        '비우면 -e ROS_DOMAIN_ID 를 넣지 않는다(이미지 기본값).',
                    child: TextField(
                      controller: _domainIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ROS_DOMAIN_ID',
                        hintText: '42',
                        helperText: 'Autoware 와 일치',
                        prefixIcon: Icon(Icons.lan_outlined, size: 18),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      style:
                          const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: 'Autoware 의 RMW 와 같아야 한다. 비우면 이미지 기본값'
                        '(FastDDS). 우측 ▾ 로 설치된 구현을 고를 수 있다.',
                    child: TextField(
                      controller: _rmwCtrl,
                      decoration: InputDecoration(
                        labelText: 'RMW_IMPLEMENTATION',
                        hintText: kAutowareRmw,
                        helperText: 'fastrtps · cyclonedds — ▾ 에서 선택',
                        prefixIcon: const Icon(Icons.hub_outlined, size: 18),
                        // 설치된 구현을 목록으로 보여준다(직접 입력도 그대로 가능).
                        suffixIcon: PopupMenuButton<String>(
                          tooltip: '설치된 RMW 선택',
                          icon: const Icon(Icons.arrow_drop_down, size: 22),
                          position: PopupMenuPosition.under,
                          onSelected: (v) => setState(() {
                            _rmwCtrl.text = v;
                          }),
                          itemBuilder: (_) => [
                            for (final (value, label) in kRmwChoices)
                              PopupMenuItem<String>(
                                value: value,
                                child: Text(label,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                          ],
                        ),
                        isDense: true,
                      ),
                      style:
                          const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 패널 설정: 저장 / 되돌리기 ───────────────────────────────────────────

  /// 화면의 모든 값을 하나의 [AppConfig] 로 모은다.
  AppConfig _formConfig() => widget.cfg.copyWith(
        image: _imageCtrl.text.trim(),
        containerName: _containerCtrl.text.trim(),
        aglOutput: _outputCtrl.text.trim(),
        rvizAppId: _rvizAppIdCtrl.text.trim(),
        homeAppId: _homeAppIdCtrl.text.trim(),
        pollIntervalSec:
            int.tryParse(_pollCtrl.text.trim()) ?? widget.cfg.pollIntervalSec,
        dockerRunArgs: dockerArgsFromText(_dockerArgsCtrl.text),
        defaultDomainId: _domainIdCtrl.text.trim(),
        rvizConfigPath: _rvizConfigCtrl.text.trim(),
        rmwImplementation: _rmwCtrl.text.trim(),
        // 저장 시점부터 이 도메인은 사용자가 고른 값이다 → 런처 Settings 로
        // 덮어쓰지 않는다(AppConfig.withDomainId).
        domainIdFromUser: true,
      );

  /// 현재 값을 사용자 설정 파일에 쓰고, 실행 중인 컨트롤러에도 즉시 반영한다.
  Future<void> _saveSettings() async {
    setState(() {
      _savingCfg = true;
      _cfgMsg = null;
    });
    final cfg = _formConfig();
    final err = await _userCfg.save(cfg);
    if (err == null) _ctrl.applyConfig(cfg);
    if (!mounted) return;
    setState(() {
      _savingCfg = false;
      _cfgMsg = err == null
          ? '저장됨 → ${_userCfg.path} (다음 Start 부터 적용)'
          : '저장 실패: $err';
    });
  }

  /// 저장본을 치우고 사이트 기본값(/etc → 코드 기본값)으로 되돌린다.
  Future<void> _resetSettings() async {
    setState(() {
      _savingCfg = true;
      _cfgMsg = null;
    });
    final err = await _userCfg.reset();
    final base = await loadConfig(const <String>[]);
    if (err == null) _ctrl.applyConfig(base);
    if (!mounted) return;
    setState(() {
      _savingCfg = false;
      if (err == null) {
        _imageCtrl.text = base.image;
        _containerCtrl.text = base.containerName;
        _outputCtrl.text = base.aglOutput;
        _rvizAppIdCtrl.text = base.rvizAppId;
        _homeAppIdCtrl.text = base.homeAppId;
        _pollCtrl.text = '${base.pollIntervalSec}';
        _dockerArgsCtrl.text = dockerArgsToText(base.dockerRunArgs);
        _domainIdCtrl.text = base.defaultDomainId;
        _rvizConfigCtrl.text = base.rvizConfigPath.isEmpty
            ? kAutowareRvizConfig
            : base.rvizConfigPath;
        _rmwCtrl.text =
            base.rmwImplementation.isEmpty ? kAutowareRmw : base.rmwImplementation;
        _cfgMsg = '기기 기본값으로 되돌림 (변경분은 .bak 으로 보관)';
      } else {
        _cfgMsg = '되돌리기 실패: $err';
      }
    });
  }

  /// 컨테이너 기동에 쓰이는 **모든 옵션**을 편집·저장하는 카드.
  /// Run Options(위 카드)가 이번 기동에만 쓰이는 값이라면, 여기 값은 저장하면
  /// 재기동 후에도 유지된다 — 저장 위치는 쓰기 가능한 XDG 설정 디렉토리다.
  Widget _buildSettingsCard(BuildContext context) {
    // 각 필드 아래에 **무엇을 바꾸는 값인지** 한 줄 설명을 붙인다 — 이름만으로는
    // rvizAppId/aglOutput 처럼 뜻이 드러나지 않는 것들이 있다.
    Widget field(String label, TextEditingController c,
            {String? hint, String? help, int maxLines = 1}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                maxLines: maxLines,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
              if (help != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 2),
                  child: Text(help,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ),
            ],
          ),
        );

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings_outlined, size: 20),
                SizedBox(width: 8),
                Text('패널 설정 (영구 저장)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '저장하면 ${_userCfg.path} 에 기록되어 재기동 후에도 유지됩니다. '
              '"기본값으로" 를 누르면 ${_userCfg.defPath} (기기 기본값)로 돌아갑니다.',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
            const SizedBox(height: 12),
            field('image', _imageCtrl,
                hint: 'registry.obigo.com/oss/rviz2-agl:latest',
                help: 'Start 가 띄울 rviz2 컨테이너 이미지. 태그를 바꾸면 다음 Start 부터 적용된다.'),
            field('containerName', _containerCtrl,
                hint: 'rviz2',
                help: 'docker run --name · stop · logs 의 대상 이름. 패널이 이 이름으로 상태를 조회한다.'),
            Row(children: [
              Expanded(
                  child: field('aglOutput', _outputCtrl,
                      hint: 'DP-1',
                      help: 'rviz2 를 띄울 화면(agl-shell output). 보드는 DP-1.')),
              const SizedBox(width: 10),
              Expanded(
                  child: field('pollIntervalSec', _pollCtrl,
                      hint: '3', help: '컨테이너 상태를 다시 확인하는 주기(초).')),
            ]),
            Row(children: [
              Expanded(
                  child: field('rvizAppId', _rvizAppIdCtrl,
                      hint: 'wlroots',
                      help: 'rviz2 창의 app_id. cage 가 만드는 이름이라 보통 그대로 둔다.')),
              const SizedBox(width: 10),
              Expanded(
                  child: field('homeAppId', _homeAppIdCtrl,
                      hint: 'hmi_launcher',
                      help: '홈 버튼으로 돌아갈 런처의 app_id.')),
            ]),
            field('dockerRunArgs', _dockerArgsCtrl,
                hint: '--net=host',
                help: 'docker run 에 그대로 넘길 인자. **한 줄에 하나**, 값이 있으면 같은 줄에 쓴다 '
                    '(예: --user 1001:1001).',
                maxLines: 8),
            if (_cfgMsg != null) ...[
              Text(_cfgMsg!,
                  style: TextStyle(
                      fontSize: 12,
                      color: _cfgMsg!.contains('실패')
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669))),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: const Key('panel_settings_reset'),
                  onPressed: _savingCfg ? null : _resetSettings,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('기본값으로'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('panel_settings_save'),
                  onPressed: _savingCfg ? null : _saveSettings,
                  icon: _savingCfg
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_savingCfg ? '저장 중' : '저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fill the option fields with the settings that connect this rviz2 to the
  /// Autoware graph on board 151 and load the bundled autoware.rviz layout.
  /// Values are editable afterwards (e.g. change domain to 0 for oss-mmf-ext-ros2).
  void _applyAutowarePreset() {
    setState(() {
      _domainIdCtrl.text = kAutowareDomainId;
      _rmwCtrl.text = kAutowareRmw;
      _rvizConfigCtrl.text = kAutowareRvizConfig;
    });
  }

  // ─── Right panel: docker logs ─────────────────────────────────────────────

  Widget _buildLogPanel(BuildContext context) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.article_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'docker logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Obx(() => Text(
                      '${_ctrl.logs.length} lines',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    )),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined, size: 20),
                  tooltip: 'Reload logs',
                  onPressed: _ctrl.tailLogs,
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 20),
                  tooltip: 'Clear log',
                  onPressed: () => _ctrl.logs.clear(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (_ctrl.logs.isEmpty) {
                return Center(
                  child: Text(
                    'No log lines yet.\nPress Start or reload.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                );
              }
              return ListView.builder(
                controller: _logScrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _ctrl.logs.length,
                itemBuilder: (ctx, i) {
                  final line = _ctrl.logs[i];
                  return _LogLineRow(line: line);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Private action helpers ───────────────────────────────────────────────

  /// Collect option form values then call [Rviz2Controller.start].
  ///
  /// Each non-empty field becomes a `-e KEY=VALUE` on the `docker run`:
  ///   ROS_DOMAIN_ID / RMW_IMPLEMENTATION / RVIZ_CONFIG (entrypoint → `rviz2 -d`).
  void _onStart() {
    final extraEnv = <String, String>{};
    final domainId = _domainIdCtrl.text.trim();
    if (domainId.isNotEmpty) {
      extraEnv['ROS_DOMAIN_ID'] = domainId;
    }
    final rmw = _rmwCtrl.text.trim();
    if (rmw.isNotEmpty) {
      extraEnv['RMW_IMPLEMENTATION'] = rmw;
    }
    final rvizConfig = _rvizConfigCtrl.text.trim();
    if (rvizConfig.isNotEmpty) {
      extraEnv['RVIZ_CONFIG'] = rvizConfig;
    }
    // Run Options 를 **파일에 남긴다** — 그러지 않으면 앱을 다시 띄울 때
    // config.json 에 없는 값이라 프리필이 이전 값으로 돌아가고, 사용자가 방금
    // 고른 도메인으로 다시 Start 하려면 매번 타이핑해야 했다(사용자 지적).
    //
    // 저장 시점을 "Start" 로 잡은 이유: 이 세 값은 `docker run` 인자이므로
    // **실제로 그 값으로 띄운 순간**이 기억할 가치가 생기는 시점이다. 타이핑
    // 도중(onChanged)에 쓰면 반쯤 지운 값이 저장된다.
    //
    // ⚠️ 부수 효과가 하나 있다: 저장되면 `domainIdFromUser` 가 켜져
    // **런처 Settings 의 도메인이 더 이상 이 패널을 덮어쓰지 않는다**
    // (AppConfig.withDomainId). 패널에서 고른 값이 이기는 것이 의도다 —
    // 되돌리려면 아래 "기기 기본값으로" 로 저장분을 치운다.
    unawaited(_persistRunOptions());
    // 기동 직후에도 패널 사각형에 띄운다 — 전체 화면이면 런처가 가려져 사이드바
    // 탭도, 'View rviz2' 도 누를 수 없다(보드 실측).
    _ctrl.start(extraEnv: extraEnv, rect: _panelRect());
  }

  /// Start 시 Run Options 를 사용자 설정 파일에 반영한다.
  ///
  /// 실패해도 기동을 막지 않는다 — rviz2 는 이미 뜬 값으로 돌고 있고, 못 쓴 것은
  /// "다음 실행에 기억되지 않는다"는 편의 손실일 뿐이다. 대신 사유를 화면에 남긴다.
  Future<void> _persistRunOptions() async {
    final cfg = _formConfig();
    final err = await _userCfg.save(cfg);
    if (err == null) _ctrl.applyConfig(cfg);
    if (!mounted) return;
    setState(() {
      _cfgMsg = err == null
          ? 'Run Options 저장됨 → ${_userCfg.path}'
          : 'Run Options 저장 실패(기동은 계속): $err';
    });
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

/// One-line "what to do now" hint shown under the state badge.
String _stateHint(ContainerState s) {
  switch (s) {
    case ContainerState.running:
      return 'Running — tap "View rviz2" to show it fullscreen.';
    case ContainerState.notInstalled:
    case ContainerState.exited:
    case ContainerState.created:
      return 'Stopped — tap "Start" to launch rviz2.';
  }
}

class _ContainerStateRow extends StatelessWidget {
  const _ContainerStateRow({required this.info});
  final ContainerInfo info;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    switch (info.state) {
      case ContainerState.running:
        badgeColor = Colors.green.shade600;
        break;
      case ContainerState.exited:
        badgeColor = Colors.grey.shade600;
        break;
      case ContainerState.created:
        badgeColor = Colors.orange.shade600;
        break;
      case ContainerState.notInstalled:
        badgeColor = Colors.blueGrey.shade400;
        break;
    }

    // **한 줄** 로 유지한다 — 변경시각을 아래 줄에 붙이면 상태에 따라 행 높이가 달라져
    // 아래의 버튼들이 밀린다(실측 20px). 배지 / exit / 변경시각을 같은 행에 둔다.
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            info.state.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (info.state == ContainerState.exited &&
            info.exitCode != null &&
            info.exitCode != 0) ...[
          const SizedBox(width: 8),
          Text(
            'exit=${info.exitCode}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
              fontFamily: 'monospace',
            ),
          ),
        ],
        const Spacer(),
        if (info.lastChangedAt != null)
          Text(
            _fmtTime(info.lastChangedAt!),
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.outline),
          ),
      ],
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $h:$m:$s';
  }
}

class _LogLineRow extends StatelessWidget {
  const _LogLineRow({required this.line});
  final LogLine line;

  @override
  Widget build(BuildContext context) {
    // ERR(빨강) / WARN(주황) / OUT(파랑) — 정보성 stderr 가 붉게 보이지 않게 한다.
    final levelColor = line.level >= 40
        ? Colors.red.shade700
        : line.level >= 30
            ? Colors.orange.shade800
            : Colors.blue.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level badge
          SizedBox(
            width: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: levelColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                line.levelLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: levelColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Timestamp
          Text(
            _fmtTs(line.ts),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: Text(
              line.msg,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTs(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
