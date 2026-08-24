import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
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
  });

  final AppConfig cfg;

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

  // Log auto-scroll.
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    // 런처 Settings 의 DDS domain 이 cfg 로 내려온다(단독 실행 시 kFallbackDomainId).
    _domainIdCtrl = TextEditingController(text: widget.cfg.defaultDomainId);

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
    _logScrollCtrl.dispose();
    super.dispose();
  }

  /// 상단(제어+옵션) 영역 높이 — 핸들 드래그로 조절한다. 로그는 남은 공간을 모두 쓴다.
  /// null 이면 **내용 높이에 맞춰 자동**(카드 두 장이 나란히 = 약 200px). 사용자가 핸들을
  /// 끌면 그 값이 들어가 고정된다. 더블클릭으로 자동으로 되돌린다.
  /// (고정 기본값 300 을 쓰면 카드가 200 인 경우 100px 빈 공간이 남았다 — 실측)
  double? _topHeight;
  static const double _kTopMin = 150;

  /// 상단/로그 경계의 드래그 핸들. 위로 끌면 로그가 커지고 아래로 끌면 상단이 커진다.
  Widget _buildLogResizeHandle(
      BuildContext context, double maxTop, double currentTop) {
    final outline = Theme.of(context).colorScheme.outline;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => setState(() {
          // 자동(null) 상태에서 처음 끌면 현재 렌더 높이를 기준으로 이어받는다.
          _topHeight =
              ((_topHeight ?? currentTop) + d.delta.dy).clamp(_kTopMin, maxTop);
        }),
        onDoubleTap: () => setState(() => _topHeight = null), // 자동으로 복귀
        child: Tooltip(
          message: '드래그로 로그 영역 높이 조절 (더블클릭 = 자동 높이)',
          child: SizedBox(
            height: 18,
            child: Center(
              child: Container(
                width: 56,
                height: 4,
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
            // 위: 제어 + 실행 옵션(좌우) / 아래: docker logs(전체 폭).
            // 사이의 핸들을 끌어 **로그 영역 높이를 조절**한다 — 상단 높이(_topHeight)를
            // 바꾸고 로그는 Expanded 로 남은 공간을 채우므로 중간에 빈 틈이 생기지 않는다.
            final maxTop = (c.maxHeight - 180).clamp(_kTopMin, c.maxHeight);
            final fixedTop = _topHeight?.clamp(_kTopMin, maxTop);
            // 상단 내용(카드 2장 + 에러 배너)
            final topContent = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 48, child: _buildStatusCard(context)),
                    const SizedBox(width: 12),
                    Expanded(flex: 52, child: _buildOptionsCard(context)),
                  ],
                ),
                _buildErrorBanner(context),
              ],
            );
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 자동: 내용 높이만 차지(빈 공간 없음) / 지정: 그 높이로 고정 + 스크롤
                  if (fixedTop == null)
                    topContent
                  else
                    SizedBox(
                      height: fixedTop,
                      child: SingleChildScrollView(child: topContent),
                    ),
                  _buildLogResizeHandle(context, maxTop, fixedTop ?? 200),
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
        _buildOptionsCard(context),
        const Spacer(),
        _buildErrorBanner(context),
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
              '다음 Start 에 적용됩니다. 아래 값은 Autoware (151) 프리셋 기준입니다 — '
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
                    message: 'Autoware 와 같아야 한다. adsw 파티션 = 42, '
                        'oss-mmf-ext-ros2 = 0. 비우면 0.',
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
    // 기동 직후에도 패널 사각형에 띄운다 — 전체 화면이면 런처가 가려져 사이드바
    // 탭도, 'View rviz2' 도 누를 수 없다(보드 실측).
    _ctrl.start(extraEnv: extraEnv, rect: _panelRect());
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
