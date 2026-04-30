import 'package:flutter/material.dart';

import 'package:ota_monitor/controller/settings_controller.dart';
import 'package:ota_monitor/theme/app_palette.dart';

/// F008: rosbridge WebSocket URL settings + theme picker.
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
          backgroundColor: palette.errorBg,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리셋 실패: $e'),
          backgroundColor: palette.errorBg,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Update the live palette immediately and persist asynchronously.
  void _onThemeChanged(String? next) {
    if (next == null || next == palette.name) return;
    paletteNotifier.value = Palette.fromName(next);
    widget.controller.applyTheme(next).catchError((e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테마 저장 실패: $e'),
          backgroundColor: palette.errorBg,
        ),
      );
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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

  Widget _buildUrlCard(Palette p) {
    return Container(
      key: const Key('card_settings_ws_url'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cable, color: p.accentBlue),
              const SizedBox(width: 12),
              Text(
                'rosbridge WebSocket URL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current: ${widget.currentUrlProvider()}',
            key: const Key('text_settings_current_url'),
            style: TextStyle(
              fontSize: 14,
              color: p.textTertiary,
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
              fillColor: p.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
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
            style: TextStyle(
              color: p.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ⓘ ws:// 또는 wss:// 로 시작해야 합니다',
            style: TextStyle(fontSize: 12, color: p.textTertiary),
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
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('btn_settings_reset'),
                onPressed: _busy ? null : _onReset,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset to default'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.textPrimary,
                  side: BorderSide(color: p.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '💾 변경값은 config.json 에 저장되어 다음 실행 시 유지됨',
            key: const Key('text_settings_persistence_note'),
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(Palette p) {
    return Container(
      key: const Key('card_settings_theme'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: p.accentBlue),
              const SizedBox(width: 12),
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Palette>(
            valueListenable: paletteNotifier,
            builder: (_, current, __) => Row(
              children: [
                _ThemeOption(
                  keyName: 'btn_theme_light',
                  label: 'Light',
                  selected: current.name == 'light',
                  onTap: () => _onThemeChanged('light'),
                ),
                const SizedBox(width: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? p.selectionBg : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? p.selectionBorder : p.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? p.primary : p.textTertiary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
