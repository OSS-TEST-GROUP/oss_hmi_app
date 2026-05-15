import 'dart:async';

import 'package:flutter/material.dart';

import '../services/gemma_chatbot_service.dart';
import '../services/system_metrics_service.dart';

class MetricsDialog extends StatefulWidget {
  const MetricsDialog({super.key, required this.loadModelMetrics});

  final Future<GemmaModelMetrics?> Function() loadModelMetrics;

  @override
  State<MetricsDialog> createState() => _MetricsDialogState();
}

class _MetricsDialogState extends State<MetricsDialog> {
  final SystemMetricsService _systemMetricsService = SystemMetricsService();
  Timer? _timer;
  SystemMetrics? _systemMetrics;
  GemmaModelMetrics? _modelMetrics;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final system = await _systemMetricsService.sample();
      final model = await widget.loadModelMetrics();
      if (!mounted) {
        return;
      }
      setState(() {
        _systemMetrics = system;
        _modelMetrics = model;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = _systemMetrics;
    final model = _modelMetrics;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Performance',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF171A20),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF393C41),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MetricRow(label: 'CPU', value: _formatPercent(system?.cpuUsage)),
              _MetricRow(label: 'GPU', value: _formatGpu(system)),
              const Divider(height: 28, color: Color(0xFFEEEEEE)),
              _MetricRow(
                label: 'Model TPS',
                value: model == null
                    ? 'Loading'
                    : '${model.tokensPerSecond.toStringAsFixed(2)} tok/s',
              ),
              _MetricRow(
                label: 'Tokens',
                value: model == null ? 'Loading' : '${model.tokens}',
              ),
              _MetricRow(
                label: 'Generation',
                value: model == null
                    ? 'Loading'
                    : '${model.generationTimeMs.toStringAsFixed(0)} ms',
              ),
              _MetricRow(
                label: 'TTFT',
                value: model == null
                    ? 'Loading'
                    : '${model.firstTokenTimeMs.toStringAsFixed(0)} ms',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF5C5E62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return 'Sampling';
    }
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatGpu(SystemMetrics? metrics) {
    if (metrics == null) {
      return 'Sampling';
    }
    final usage = metrics.gpuUsage;
    if (usage == null) {
      return metrics.gpuLabel;
    }
    return '${usage.toStringAsFixed(0)}% · ${metrics.gpuLabel}';
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF5C5E62)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF171A20),
            ),
          ),
        ],
      ),
    );
  }
}
