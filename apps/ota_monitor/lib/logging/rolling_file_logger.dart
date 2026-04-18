import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RollingFileLogger {
  RollingFileLogger({
    required this.dirPath,
    this.fileName = 'app.log',
    this.maxBytes = 10 * 1024 * 1024,
    this.maxFiles = 5,
    this.flushEvery = const Duration(seconds: 1),
    this.flushLines = 50,
  });

  final String dirPath;
  final String fileName;
  final int maxBytes;
  final int maxFiles;
  final Duration flushEvery;
  final int flushLines;

  final List<String> _buf = [];
  Timer? _flushTimer;
  IOSink? _sink;
  File? _file;
  Future<void>? _flushInFlight;
  bool _stopped = false;

  Future<void> start() async {
    await Directory(dirPath).create(recursive: true);
    _file = File('$dirPath/$fileName');

    if (await _file!.exists()) {
      final s = await _file!.length();
      if (s >= maxBytes) {
        await _rotateNow();
      }
    }

    _sink = _file!.openWrite(mode: FileMode.append);

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushEvery, (_) => unawaited(flush()));
  }

  void addLine(String line) {
    _buf.add(line);
    if (_buf.length >= flushLines) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    // Chain concurrent flushes so callers observe completion and stop() can
    // safely await any in-flight work before closing the sink.
    final previous = _flushInFlight;
    final done = Completer<void>();
    _flushInFlight = done.future;

    try {
      await previous;
      if (_stopped || _sink == null || _file == null || _buf.isEmpty) {
        return;
      }

      final lines = List<String>.from(_buf);
      _buf.clear();

      for (final line in lines) {
        if (_stopped || _sink == null) break;
        final data = '$line\n';
        final bytes = utf8.encode(data).length;

        final cur = await _file!.length();
        if (cur + bytes > maxBytes) {
          await _rotateIfNeeded(force: true);
        }
        _sink?.write(data);
      }

      await _sink?.flush();
    } finally {
      done.complete();
      if (identical(_flushInFlight, done.future)) {
        _flushInFlight = null;
      }
    }
  }

  Future<void> _rotateIfNeeded({bool force = false}) async {
    if (_sink == null || _file == null) return;

    if (!force) {
      final size = await _file!.length();
      if (size < maxBytes) return;
    }

    await _sink!.flush();
    await _sink!.close();
    _sink = null;

    for (int i = maxFiles - 2; i >= 0; i--) {
      final src = i == 0
          ? File('$dirPath/$fileName')
          : File('$dirPath/$fileName.$i');
      final dst = File('$dirPath/$fileName.${i + 1}');
      if (await src.exists()) {
        if (await dst.exists()) {
          await dst.delete();
        }
        await src.rename(dst.path);
      }
    }

    _file = File('$dirPath/$fileName');
    _sink = _file!.openWrite(mode: FileMode.write);
  }

  Future<void> _rotateNow() async {
    for (int i = maxFiles - 2; i >= 0; i--) {
      final src = i == 0
          ? File('$dirPath/$fileName')
          : File('$dirPath/$fileName.$i');
      final dst = File('$dirPath/$fileName.${i + 1}');
      if (await src.exists()) {
        if (await dst.exists()) {
          await dst.delete();
        }
        await src.rename(dst.path);
      }
    }
    _file = File('$dirPath/$fileName');
  }

  Future<void> stop() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    // Drain anything still buffered, but also wait for an in-flight flush
    // from a concurrent addLine() before closing the sink.
    await flush();
    await _flushInFlight;
    _stopped = true;
    await _sink?.close();
    _sink = null;
  }
}
