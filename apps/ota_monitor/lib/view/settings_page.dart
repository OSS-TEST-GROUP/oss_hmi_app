import 'package:flutter/material.dart';

import 'package:ota_monitor/controller/settings_controller.dart';

/// F008: rosbridge WebSocket URL settings tab.
///
/// Widget keys follow the F020 spec at docs/ux/widget-keys.md §7.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.currentUrlProvider,
  });

  final SettingsController controller;

  /// Returns the current effective URL. Called on every build so the page
  /// reflects the live RosKeeper state after applyUrl/resetToDefault.
  final String Function() currentUrlProvider;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _urlField;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlField = TextEditingController(text: widget.currentUrlProvider());
    _urlField.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _urlField.dispose();
    super.dispose();
  }

  bool get _isValid {
    // CONSIDER #1: trim whitespace so a copy-pasted URL with a stray
    // trailing newline still enables Apply. Controller.applyUrl trims
    // again — both layers stay in sync.
    final v = _urlField.text.trim();
    return v.isNotEmpty && SettingsController.isValidUrl(v);
  }

  Future<void> _onApply() async {
    if (!_isValid || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.controller.applyUrl(_urlField.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '재연결 중...' : '잘못된 URL 형식입니다'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('적용 실패: $e'),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onReset() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.controller.resetToDefault();
      if (!mounted) return;
      _urlField.text = widget.currentUrlProvider();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '기본값으로 재연결 중...' : '리셋 실패'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // SHOULD #2: resetToDefault also performs file I/O and keeper
      // restart, both of which can throw. Surface failures as a SnackBar
      // exactly like _onApply so the user is never left guessing.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리셋 실패: $e'),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        key: const Key('card_settings_ws_url'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cable, color: Color(0xFF60A5FA)),
                SizedBox(width: 12),
                Text(
                  'rosbridge WebSocket URL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Current: ${widget.currentUrlProvider()}',
              key: const Key('text_settings_current_url'),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('field_settings_ws_url'),
              controller: _urlField,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: 'ws://host:9090',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _urlField.text.isEmpty
                    ? null
                    : (_isValid
                        ? null
                        : const Icon(
                            Icons.error_outline,
                            key: Key('icon_settings_invalid'),
                            color: Color(0xFFEF4444),
                          )),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ⓘ ws:// 또는 wss:// 로 시작해야 합니다',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  key: const Key('btn_settings_apply'),
                  onPressed: _isValid && !_busy ? _onApply : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const Key('btn_settings_reset'),
                  onPressed: _busy ? null : _onReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset to default'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '💾 변경값은 config.json 에 저장되어 다음 실행 시 유지됨',
              key: Key('text_settings_persistence_note'),
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
