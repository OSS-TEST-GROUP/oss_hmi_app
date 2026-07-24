import 'dart:async';
import 'dart:io';

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
  Future<void> start({Map<String, String> extraEnv = const {}}) async {
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
    //     [-e ROS_DOMAIN_ID=<val>  ...]
    //     registry.obigo.com/oss/rviz2-agl:latest
    final runArgs = <String>[
      'run',
      '-d',
      '--name', cfg.containerName,
      ...cfg.dockerRunArgs,
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

    // 3. Activate the rviz2 surface.
    await showRviz2();

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
  Future<void> showRviz2() async {
    await _activateAglSurface(cfg.rvizAppId);
  }

  /// Activate the home launcher surface via the AGL shell gRPC service.
  Future<void> showHome() async {
    await _activateAglSurface(cfg.homeAppId);
  }

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

  void _appendLine(String text, {required bool isErr}) {
    if (text.isEmpty) return;
    logs.add(LogLine(
      level: isErr ? 40 : 20,
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
