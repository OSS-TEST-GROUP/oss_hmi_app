import 'package:flutter/material.dart';

import '../controller/settings_controller.dart';
import '../theme/lfc_palette.dart';

/// F014 / S5-4: rosbridge WebSocket URL editor + theme picker, rendered
/// inside a Dialog from the header Settings button. Stateful only for
/// the busy flag + text field controller.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.currentUrlProvider,
  });

  final SettingsController controller;

  /// Live URL — called on every build so the page reflects the post-apply
  /// keeper state.
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
    final v = _urlField.text.trim();
    return v.isNotEmpty && SettingsController.isValidUrl(v);
  }

  Future<void> _onApply() async {
    if (!_isValid || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.controller.applyUrl(_urlField.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '재연결 중...' : '잘못된 URL 형식입니다'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('적용 실패: $e'),
        backgroundColor: palette.errorBg,
      ));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '기본값으로 재연결 중...' : '리셋 실패'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('리셋 실패: $e'),
        backgroundColor: palette.errorBg,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Update the live palette immediately and persist asynchronously.
  void _onThemeChanged(String? next) {
    if (next == null || next == palette.name) return;
    paletteNotifier.value = LfcPalette.fromName(next);
    widget.controller.applyTheme(next).catchError((e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('테마 저장 실패: $e'),
        backgroundColor: palette.errorBg,
      ));
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUrlCard(p),
          const SizedBox(height: 16),
          _buildThemeCard(p),
        ],
      ),
    );
  }

  Widget _buildUrlCard(LfcPalette p) {
    return Container(
      key: const Key('card_settings_ws_url'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cable, color: p.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'rosbridge WebSocket URL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Current: ${widget.currentUrlProvider()}',
            key: const Key('text_settings_current_url'),
            style: TextStyle(
              fontSize: 12,
              color: p.subtext,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('field_settings_ws_url'),
            controller: _urlField,
            enabled: !_busy,
            decoration: InputDecoration(
              hintText: 'ws://host:9090',
              hintStyle: TextStyle(color: p.textPlaceholder),
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: p.panelBorder),
              ),
              suffixIcon: _urlField.text.isEmpty
                  ? null
                  : (_isValid
                      ? null
                      : Icon(
                          Icons.error_outline,
                          key: const Key('icon_settings_invalid'),
                          color: p.error,
                        )),
            ),
            style: TextStyle(color: p.text, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          Text(
            'ⓘ ws:// 또는 wss:// 로 시작해야 합니다',
            style: TextStyle(fontSize: 11, color: p.subtext),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                key: const Key('btn_settings_apply'),
                onPressed: _isValid && !_busy ? _onApply : null,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Apply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor:
                      p.brightness == Brightness.dark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const Key('btn_settings_reset'),
                onPressed: _busy ? null : _onReset,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset to default'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.text,
                  side: BorderSide(color: p.panelBorder),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '💾 변경값은 config.json 에 저장되어 다음 실행 시 유지됨',
            key: const Key('text_settings_persistence_note'),
            style: TextStyle(fontSize: 11, color: p.subtext),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(LfcPalette p) {
    return Container(
      key: const Key('card_settings_theme'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: p.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<LfcPalette>(
            valueListenable: paletteNotifier,
            builder: (_, current, __) => Row(
              children: [
                _ThemeOption(
                  keyName: 'btn_theme_light',
                  label: 'Light',
                  selected: current.name == 'light',
                  onTap: () => _onThemeChanged('light'),
                ),
                const SizedBox(width: 10),
                _ThemeOption(
                  keyName: 'btn_theme_dark',
                  label: 'Dark',
                  selected: current.name == 'dark',
                  onTap: () => _onThemeChanged('dark'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.keyName,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? p.accent : p.panelBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? p.accent : p.subtext,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: p.text,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
