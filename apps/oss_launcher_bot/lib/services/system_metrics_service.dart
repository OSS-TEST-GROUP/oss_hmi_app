import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SystemMetrics {
  const SystemMetrics({
    required this.cpuUsage,
    required this.gpuUsage,
    required this.gpuLabel,
  });

  final double? cpuUsage;
  final double? gpuUsage;
  final String gpuLabel;
}

class SystemMetricsService {
  _CpuSnapshot? _previousCpu;

  Future<SystemMetrics> sample() async {
    final results = await Future.wait<Object?>([_sampleCpu(), _sampleGpu()]);

    return SystemMetrics(
      cpuUsage: results[0] as double?,
      gpuUsage: (results[1]! as _GpuSample).usage,
      gpuLabel: (results[1]! as _GpuSample).label,
    );
  }

  Future<double?> _sampleCpu() async {
    final snapshot = await _readCpuSnapshot();
    if (snapshot == null) {
      return null;
    }

    final previous = _previousCpu;
    _previousCpu = snapshot;
    if (previous == null) {
      return null;
    }

    final totalDelta = snapshot.total - previous.total;
    final idleDelta = snapshot.idle - previous.idle;
    if (totalDelta <= 0) {
      return null;
    }

    return ((totalDelta - idleDelta) / totalDelta * 100)
        .clamp(0, 100)
        .toDouble();
  }

  Future<_CpuSnapshot?> _readCpuSnapshot() async {
    try {
      final line = await File('/proc/stat')
          .openRead()
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.startsWith('cpu '));
      final parts = line.trim().split(RegExp(r'\s+')).skip(1).toList();
      final values = parts.map((part) => int.tryParse(part) ?? 0).toList();
      if (values.length < 4) {
        return null;
      }

      final idle = values[3] + (values.length > 4 ? values[4] : 0);
      final total = values.fold<int>(0, (sum, value) => sum + value);
      return _CpuSnapshot(total: total, idle: idle);
    } catch (_) {
      return null;
    }
  }

  Future<_GpuSample> _sampleGpu() async {
    for (final path in _gpuLoadCandidates) {
      final sample = await _sampleGpuLoadFile(path);
      if (sample != null) {
        return sample;
      }
    }

    return const _GpuSample(label: 'Unavailable');
  }

  Future<_GpuSample?> _sampleGpuLoadFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }

      final raw = await file.readAsString();
      final usage = _parseGpuUsage(raw);
      if (usage == null) {
        return null;
      }

      return _GpuSample(usage: usage, label: 'GPU');
    } catch (_) {
      return null;
    }
  }

  double? _parseGpuUsage(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final value = double.tryParse(normalized.split(RegExp(r'\s+')).first);
    if (value == null) {
      return null;
    }

    final percent = value > 100 ? value / 10 : value;
    return percent.clamp(0, 100).toDouble();
  }

  static const List<String> _gpuLoadCandidates = [
    '/sys/devices/gpu.0/load',
    '/sys/devices/platform/gpu.0/load',
    '/sys/devices/platform/17000000.gpu/load',
    '/sys/kernel/debug/gpu.0/load',
  ];
}

class _CpuSnapshot {
  const _CpuSnapshot({required this.total, required this.idle});

  final int total;
  final int idle;
}

class _GpuSample {
  const _GpuSample({this.usage, required this.label});

  final double? usage;
  final String label;
}
