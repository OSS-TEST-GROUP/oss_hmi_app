import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:get/get.dart';
import 'package:grpc/grpc.dart';

import '../config/app_config.dart';
import '../data/rviz2_data.dart';
import '../generated/agl_shell.pbgrpc.dart';

/// Controls the local rviz2 Docker container directly via the `docker` CLI.
/// Screen switching (showRviz2 / showHome) uses the AGL shell gRPC service
/// running at 127.0.0.1:14005 (plaintext / insecure).
///
/// ## Why gRPC instead of agl-shell-activator binary?
/// The `agl-shell-activator` binary depends on AGL-only shared libraries
/// (libgrpc, libprotobuf, ~20 libabsl_*.so) that are not present inside the
/// hmi_launcher Ubuntu 24.04 container.  The gRPC endpoint itself is reachable
/// because the container runs with --net=host.
///
/// ## docker control
/// All subprocess calls go through [_run], which wraps Process.run with a
/// try/catch guard so failures surface as [lastError] instead of exceptions.
///
/// ## State machine
/// [refreshStatus] polls `docker inspect` every [AppConfig.pollIntervalSec]
/// and updates [container].  Optimistic state mutations are applied immediately
/// on [start]/[stop] so the UI responds instantly.
///
/// ## Log streaming
/// [tailLogs] runs `docker logs --tail 300 <name>` once and stores the
/// output into [logs].  A follow-up `docker logs -f` stream is started and
/// kept alive while the container is running; lines are appended to [logs]
/// (ring-buffered at [_logCapacity]).
class Rviz2Controller extends GetxController {
  Rviz2Controller({required this.cfg});

  final AppConfig cfg;

  // ─── Public observable state ────────────────────────────────────────────

  /// Current docker container state + exit code.
  final Rx<ContainerInfo> container =
      ContainerInfo(name: 'rviz2').obs;

  /// docker logs ring buffer — newest line at the end (auto-scroll to bottom).
  final RxList<LogLine> logs = <LogLine>[].obs;

  /// Last subprocess or gRPC error message, or null.
  final RxnString lastError = RxnString();

  static const int _logCapacity = 300;

  // ─── AGL gRPC client ─────────────────────────────────────────────────────

  /// gRPC channel to the AGL shell manager service.
  /// Created lazily; closed in [onClose].
  ClientChannel? _grpcChannel;
  AglShellManagerServiceClient? _aglClient;

  /// Obtain (or create) the gRPC client connected to 127.0.0.1:14005.
  AglShellManagerServiceClient _getAglClient() {
    if (_aglClient != null) return _aglClient!;
    _grpcChannel = ClientChannel(
      '127.0.0.1',
      port: 14005,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _aglClient = AglShellManagerServiceClient(_grpcChannel!);
    return _aglClient!;
  }

  // ─── Internal ────────────────────────────────────────────────────────────

  Timer? _pollTimer;
  Process? _logsProcess;
  bool _logFollowActive = false; // ignore: unused_field

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    // Initial poll then periodic.
    refreshStatus();
    _pollTimer = Timer.periodic(
      Duration(seconds: cfg.pollIntervalSec),
      (_) => refreshStatus(),
    );
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _stopLogFollow();
    _grpcChannel?.shutdown();
    super.onClose();
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Poll `docker inspect` and update [container].
  ///
  /// Exit code is also captured so the UI can show `exit=<n>` when stopped.
  Future<void> refreshStatus() async {
    final res = await _run('docker', [
      'inspect',
      '-f',
      '{{.State.Status}}|||{{.State.ExitCode}}',
      cfg.containerName,
    ]);

    if (res == null || res.exitCode != 0) {
      // Container not found / docker unavailable → synthetic notInstalled.
      _updateContainer(ContainerState.notInstalled, null);
      return;
    }

    final parts = res.stdout.toString().trim().split('|||');
    final status = parts.isNotEmpty ? parts[0].trim() : '';
    final exitCodeRaw =
        parts.length > 1 ? int.tryParse(parts[1].trim()) : null;

    final newState = ContainerState.fromDockerStatus(status);
    _updateContainer(newState, exitCodeRaw);
  }

  /// Remove any existing container then run rviz2, then bring it to front.
  ///
  /// Sequence:
  ///   1. `docker rm -f rviz2`   (ignore error — may not exist)
  ///   2. `docker run -d --name rviz2 <cfg.dockerRunArgs> [extraEnv] <cfg.image>`
  ///   3. [showRviz2]
  ///
  /// [extraEnv] is a map of additional `-e KEY=VALUE` tokens to append before
  /// the image name (e.g. `{'ROS_DOMAIN_ID': '42'}`).
  /// [rect] 는 [showRviz2] 로 그대로 넘어간다 — 기동 직후에도 **패널 사각형**에
  /// 띄워야 런처 사이드바가 살아 있어 앱 전환이 가능하다(전체 화면이면 런처가
  /// 가려져 'View rviz2' 조차 누를 수 없다 — 보드 실측).
  Future<void> start({Map<String, String> extraEnv = const {}, Rect? rect}) async {
    _setOptimisticState(ContainerState.running);
    lastError.value = null;

    // 1. Clean up any stopped container with the same name.
    await _run('docker', ['rm', '-f', cfg.containerName]);

    // 2. Build the full arg list.
    //
    // Full docker run command that will be executed:
    //   docker run -d --name rviz2
    //     --net=host --ipc=host
    //     --user 1001:1001 --group-add 44
    //     -v /run/user/1001:/host-xdg
    //     -e XDG_RUNTIME_DIR=/host-xdg
    //     -e WAYLAND_DISPLAY=wayland-0
    //     -e HOME=/tmp
    //     -e LIBGL_ALWAYS_SOFTWARE=1
    //     [-e ROS_DOMAIN_ID=<val>]        # match Autoware (adsw=42 / ext-ros2=0)
    //     [-e RMW_IMPLEMENTATION=<val>]   # match Autoware RMW (default FastDDS)
    //     [-e RVIZ_CONFIG=<path>]         # entrypoint → rviz2 -d <path> (autoware.rviz)
    //     registry.obigo.com/oss/rviz2-agl:latest   # = autoware runtime image
    final runArgs = <String>[
      'run',
      '-d',
      '--name', cfg.containerName,
      ...cfg.dockerRunArgs,
      // 패널 사각형에 띄울 때는 **entrypoint 의 풀화면 롤을 끈다**. 풀화면 롤을 받으면
      // 그 레이어에 고정돼 Float/Scale 이 무시되고 화면 전체를 덮는다(보드 실측).
      if (rect != null) ...['-e', 'AGL_SHELL_FULLSCREEN=0'],
      // Caller-supplied env vars (e.g. ROS_DOMAIN_ID).
      ...extraEnv.entries.expand((e) => ['-e', '${e.key}=${e.value}']),
      cfg.image,
    ];

    final res = await _run('docker', runArgs);
    if (res == null || res.exitCode != 0) {
      // Roll back optimistic state and surface error.
      await refreshStatus();
      return;
    }

    // 3. 서페이스가 매핑된 뒤에 기하를 적용한다 — **매핑 전 호출은 무시된다**(보드 실측:
    //    docker run 직후 Float/Scale 을 보내면 cage 가 기본 1280x720 으로 남는다).
    if (rect != null) await _waitForRvizSurface();
    await showRviz2(rect: rect);

    // 4. Start log follow.
    await tailLogs();
  }

  /// Stop the rviz2 container, then activate the home screen.
  Future<void> stop() async {
    _setOptimisticState(ContainerState.exited);
    lastError.value = null;

    _stopLogFollow();

    final res = await _run('docker', ['stop', cfg.containerName]);
    if (res == null || res.exitCode != 0) {
      await refreshStatus();
      return;
    }

    await showHome();
    await refreshStatus();
  }

  /// Activate the rviz2 cage surface via the AGL shell gRPC service.
  ///
  /// Sends ActivateApp(app_id=cfg.rvizAppId, output_name=cfg.aglOutput)
  /// to 127.0.0.1:14005.  Failures are surfaced in [lastError] only (never
  /// thrown to the UI layer).
  ///
  /// ⚠ Field numbers (app_id=1, output_name=2) are reconstructed from the
  ///   compiled .pb — verify on hardware before production use.
  /// cage 서페이스가 매핑될 때까지 기다린다.
  ///
  /// 앵커는 entrypoint 가 **cage 중첩 소켓을 확인한 뒤** 찍는 homebar 마커다. 그 앞의
  /// "cage + rviz2 시작" 은 소켓 생성 전이라 앵커로 쓸 수 없다. 못 찾으면 [timeout] 뒤
  /// 그냥 진행한다(기하가 안 먹을 뿐, 컨테이너는 정상).
  Future<void> _waitForRvizSurface({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final res = await _run('docker', ['logs', '--tail', '80', cfg.containerName]);
      final out = '${res?.stdout ?? ''}${res?.stderr ?? ''}';
      if (out.contains('homebar 표시 시도')) {
        // 첫 프레임까지 여유 — 마커 직후엔 아직 크기 협상 중일 수 있다.
        await Future<void>.delayed(const Duration(seconds: 5));
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// [rect] 를 주면 **그 사각형 안에** rviz2 를 띄운다(런처 안에 끼워 넣은 것처럼).
  /// null 이면 종전대로 전체 화면.
  ///
  /// 보드 실측(2026-08-14): agl-shell 에서 창 기하를 바꾸려면 **풀화면 롤을 먼저 풀어야**
  /// 한다 — 풀화면 상태에서는 Float/Scale 이 무시된다. 순서는
  /// `SetAppNormal → SetAppFloat(x,y) → SetAppScale(w,h) → ActivateApp`.
  /// 이렇게 띄우면 rviz2 밖(런처 사이드바·타이틀)의 터치는 런처가, 안쪽은 rviz2 가 받는다.
  Future<void> showRviz2({Rect? rect}) async {
    if (rect != null) {
      final id = cfg.rvizAppId;
      await _grpcHomebar('SetAppNormal', '{"app_id":"$id"}');
      await _grpcHomebar('SetAppFloat',
          '{"app_id":"$id","x_pos":${rect.left.round()},"y_pos":${rect.top.round()}}');
      await _grpcHomebar('SetAppScale',
          '{"app_id":"$id","width":${rect.width.round()},"height":${rect.height.round()}}');
    }
    await _activateAglSurface(cfg.rvizAppId);
    await _showHomebar();   // the home button belongs over rviz2, not the launcher
  }

  /// rviz2 서페이스를 화면에서 내린다(컨테이너는 그대로 둔다).
  ///
  /// 런처에서 **다른 앱으로 전환**할 때 쓴다. rviz2 는 런처(BG) 위에 떠 있으므로 내리지
  /// 않으면 새로 고른 앱 화면이 rviz2 뒤에 가려진다(보드 실측). 홈 버튼도 같이 숨긴다 —
  /// rviz2 가 안 보이는데 그 위의 버튼만 남으면 안 되기 때문.
  Future<void> hideRviz2() async {
    // 풀화면 롤이면 DeactivateApp 이 먹지 않는다 → 먼저 롤을 푼다(2026-08-18 실측).
    await _grpcHomebar('SetAppNormal', '{"app_id":"${cfg.rvizAppId}"}');
    await _grpcHomebar('DeactivateApp', '{"app_id":"${cfg.rvizAppId}"}');
    await _hideHomebar();
  }

  /// Activate the home launcher surface via the AGL shell gRPC service.
  ///
  /// 런처는 AGL **배경(BG) 롤**로 뜨므로(`flutter-auto --window-type BG`), 홈 복귀는
  /// "런처를 올리는" 게 아니라 **rviz2 를 내리는** 것이다 — BG 는 항상 앱 아래에 있고
  /// `ActivateApp hmi_launcher` 는 BG 서페이스에 아무 영향이 없다(보드 실측).
  /// 두 호출을 모두 보내 BG·NORMAL 두 구성에서 같은 동작을 보장한다. 또 ActivateApp 은
  /// ack 이 없고 첫 호출이 무효인 경우가 있어(실측) 멱등 재호출을 둔다.
  Future<void> showHome() async {
    // rviz2 가 풀화면 롤이면(compose/adsw 경로 기본값) DeactivateApp 이 무시된다 —
    // 화면이 그대로라 "홈이 안 먹는다"가 된다. SetAppNormal 로 롤을 먼저 푼다.
    // 재호출은 **지연 없이 연속 2회**다. 1초 지연 재호출은 그 사이에 사용자가 rviz2 를
    // 다시 띄우면 그것을 도로 내려버렸다(실측 2026-08-18).
    for (var i = 0; i < 2; i++) {
      await _grpcHomebar('SetAppNormal', '{"app_id":"${cfg.rvizAppId}"}');
      await _grpcHomebar('DeactivateApp', '{"app_id":"${cfg.rvizAppId}"}');
      await _activateAglSurface(cfg.homeAppId);
    }
    await _hideHomebar();   // hide the home button on the launcher
  }

  // ─── homebar (floating "home" button overlay) visibility ──────────────────
  // The homebar now runs **inside the rviz2 container** (integrated — it is just
  // another client of the host agl-compositor, unrelated to cage), so its
  // lifecycle matches rviz2: the button exists exactly while rviz2 does, and the
  // rviz2 entrypoint floats it as soon as its surface maps. No boot-time
  // show/hide race, no stale surface after Stop.
  //
  // It cannot tell which app is in the foreground, so we still toggle it on
  // surface switches: shown over rviz2, hidden on the launcher. grpcurl ships in
  // the rviz2 image, so we exec into that container (avoids extending this app's
  // gRPC stubs). app_id stays "homebar" — the compositor keys on app_id, not on
  // which container the client lives in.
  static const int _homebarX = 1890, _homebarY = 0;

  Future<ProcessResult?> _grpcHomebar(String method, String data) => _run(
        'docker',
        [
          'exec', cfg.containerName, 'grpcurl', '-plaintext', '-d', data,
          '127.0.0.1:14005', 'agl_shell_ipc.AglShellManagerService/$method',
        ],
      );

  /// Show the home button over rviz2.
  ///
  /// The three calls are sent twice, ~1.2 s apart. agl-shell acknowledges
  /// nothing (activate/float/deactivate return empty, and AppStatusState does
  /// not report visibility — measured), so we cannot check whether the first
  /// attempt took effect. The calls are idempotent, so re-asserting is the cheap
  /// way to survive a transient surface state (e.g. homebar restarted by adsw
  /// moments earlier and still settling). The boot-time race itself is fixed in
  /// homebar's entrypoint: it hides itself exactly once, right after its surface
  /// is mapped, so any show that arrives later — including this one — wins.
  Future<void> _showHomebar() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      await _grpcHomebar('ActivateApp',
          '{"app_id":"homebar","output_name":"${cfg.aglOutput}"}');
      await _grpcHomebar('SetAppFloat',
          '{"app_id":"homebar","x_pos":$_homebarX,"y_pos":$_homebarY}');
      await _grpcHomebar('SetAppPosition',
          '{"app_id":"homebar","x":$_homebarX,"y":$_homebarY}');
    }
  }

  Future<void> _hideHomebar() =>
      _grpcHomebar('DeactivateApp', '{"app_id":"homebar"}');

  /// Fetch the last 300 lines of container logs (stdout + stderr combined)
  /// and start a follow stream to append new lines in real time.
  ///
  /// Safe to call while [_logFollowActive] is true — it stops the previous
  /// stream first.
  Future<void> tailLogs() async {
    _stopLogFollow();
    logs.clear();

    // Initial tail — 300 lines from history.
    final tail = await _run(
      'docker',
      ['logs', '--tail', '300', cfg.containerName],
    );
    if (tail != null) {
      _appendRawLines(tail.stdout.toString(), isErr: false);
      _appendRawLines(tail.stderr.toString(), isErr: true);
    }

    // Follow stream.
    try {
      _logsProcess = await Process.start(
        'docker',
        ['logs', '-f', '--tail', '0', cfg.containerName],
      );
      _logFollowActive = true;

      _logsProcess!.stdout
          .transform(const SystemEncoding().decoder)
          .listen(_onLogChunkOut, onDone: _onFollowDone, cancelOnError: true);
      _logsProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen(_onLogChunkErr, onDone: _onFollowDone, cancelOnError: true);
    } catch (e) {
      _logFollowActive = false;
      // Not fatal — historic logs are already shown.
    }
  }

  // ─── AGL gRPC helper ─────────────────────────────────────────────────────

  /// Send ActivateApp([appId], [cfg.aglOutput]) to the AGL gRPC endpoint.
  Future<void> _activateAglSurface(String appId) async {
    try {
      final client = _getAglClient();
      final req = ActivateRequest()
        ..appId = appId
        ..outputName = cfg.aglOutput;
      await client.activateApp(req);
    } catch (e) {
      // AGL gRPC errors (e.g. surface not ready) are non-fatal — the
      // container state change itself succeeded.
      lastError.value = 'agl-shell activate "$appId": $e';
    }
  }

  // ─── docker Process helper ────────────────────────────────────────────────

  /// Run [exe] with [args].  Returns the [ProcessResult] or null on OS-level
  /// errors.  docker non-zero exits are NOT surfaced in [lastError] here
  /// because callers interpret exit codes themselves (e.g. `docker rm -f` on a
  /// non-existent container returns 1 and is expected).
  Future<ProcessResult?> _run(String exe, List<String> args) async {
    try {
      return await Process.run(exe, args);
    } catch (e) {
      lastError.value = 'Failed to run $exe: $e';
      return null;
    }
  }

  // ─── State helpers ────────────────────────────────────────────────────────

  void _updateContainer(ContainerState state, int? exitCode) {
    final info = container.value;
    final changed = info.state != state ||
        (state == ContainerState.exited && info.exitCode != exitCode);
    if (!changed) return;
    info.state = state;
    info.exitCode = (state == ContainerState.exited) ? exitCode : null;
    info.lastChangedAt = DateTime.now();
    container.refresh();
  }

  void _setOptimisticState(ContainerState state) {
    final info = container.value;
    info.state = state;
    info.exitCode = null;
    info.lastChangedAt = DateTime.now();
    container.refresh();
  }

  // ─── Log helpers ──────────────────────────────────────────────────────────

  /// 로그 한 줄의 심각도를 **내용**으로 판정한다.
  ///
  /// 왜 스트림(stderr)으로 판정하지 않는가: 이 컨테이너에서 stderr 로 나오는 것 대부분이
  /// 정상 정보다(실측) —
  ///   - homebar 의 상태 출력(`[homebar] app_id=homebar up`, `configure 0x0 max=0 fs=0`)
  ///   - cage/wlroots·XWayland 의 `[DEBUG] [xwayland/xwm.c:…]` 추적 로그
  ///   - rviz2/ROS 의 `[INFO] … Stereo is NOT SUPPORTED`
  /// 이것들을 stderr 라는 이유로 붉은 ERR 로 칠하면 패널이 온통 에러처럼 보여 실제
  /// 에러(플러그인 로드 실패 등)를 놓친다. 그래서 대괄호 레벨 태그와 키워드로 판정하고,
  /// 태그가 없는 stderr 줄은 경고(30)로 낮춘다.
  static int _levelFor(String text, bool isErr) {
    final t = text.toLowerCase();
    if (t.contains('[error]') || t.contains('[fatal]') ||
        t.contains('error:') || t.contains('failed') ||
        text.contains('❌')) {
      return 40; // 실제 에러만 붉게
    }
    if (t.contains('[warn]') || text.contains('⚠️')) return 30;
    if (t.contains('[debug]') || t.contains('[info]') ||
        text.startsWith('[homebar]') || text.startsWith('▶')) {
      return 20; // 정보/추적 로그
    }
    return isErr ? 30 : 20; // 태그 없는 stderr 는 경고까지만
  }

  void _appendLine(String text, {required bool isErr}) {
    if (text.isEmpty) return;
    logs.add(LogLine(
      level: _levelFor(text, isErr),
      name: cfg.containerName,
      msg: text,
      ts: DateTime.now(),
    ));
    if (logs.length > _logCapacity) {
      logs.removeRange(0, logs.length - _logCapacity);
    }
  }

  void _appendRawLines(String chunk, {required bool isErr}) {
    for (final line in chunk.split('\n')) {
      _appendLine(line, isErr: isErr);
    }
  }

  void _onLogChunkOut(String chunk) => _appendRawLines(chunk, isErr: false);
  void _onLogChunkErr(String chunk) => _appendRawLines(chunk, isErr: true);
  void _onFollowDone() => _logFollowActive = false;

  void _stopLogFollow() {
    try {
      _logsProcess?.kill();
    } catch (_) {}
    _logsProcess = null;
    _logFollowActive = false;
  }
}
