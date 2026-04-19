import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Quick launch chip row widget.
/// Displays up to 5 apps as clickable chips for quick access.
class QuickChipRow extends StatelessWidget {
  const QuickChipRow({
    super.key,
    required this.apps,
    required this.onAppSelected,
  });

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppSelected;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);
    final displayApps = apps.take(5).toList();

    return Container(
      key: const Key('quick_chip_row'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: LauncherTokens.b1)),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Quick Launch:',
            style: TextStyle(
              fontFamily: LauncherTokens.fontMono,
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: LauncherTokens.t3,
            ),
          ),
          ...displayApps.map((app) => _QuickChip(
                key: Key('quick_chip_${app.id}'),
                app: app,
                accentColor: accent,
                onTap: () => onAppSelected(app),
              )),
        ],
      ),
    );
  }
}

/// Individual quick launch chip widget.
class _QuickChip extends StatefulWidget {
  const _QuickChip({
    super.key,
    required this.app,
    required this.accentColor,
    required this.onTap,
  });

  final AppManifest app;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.accentColor.withOpacity(0.05)
                : LauncherTokens.bg3,
            border: Border.all(
              color: _isHovered ? widget.accentColor : LauncherTokens.b1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${widget.app.icon} ${widget.app.name}',
            style: TextStyle(
              fontFamily: LauncherTokens.fontBody,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: _isHovered ? widget.accentColor : LauncherTokens.t2,
            ),
          ),
        ),
      ),
    );
  }
}
