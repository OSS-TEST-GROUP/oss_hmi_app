import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/launcher_tokens.dart';

/// Tesla-style top bar: thin, sentence-case, monochrome.
///
/// Layout: [AGL wordmark | app context] · [vehicle strip] · [time | icons].
/// Height is fixed at [LauncherTokens.titlebarHeight] (56px).
class LauncherTitleBar extends StatelessWidget
    implements PreferredSizeWidget {
  const LauncherTitleBar({
    super.key,
    required this.appTitle,
    this.appSub,
    this.onEnterFullscreen,
  });

  final String appTitle;
  final String? appSub;

  /// When non-null, a fullscreen-toggle icon button is shown in the right
  /// group. Typically wired only while a plugin app is selected.
  final VoidCallback? onEnterFullscreen;

  @override
  Size get preferredSize =>
      const Size.fromHeight(LauncherTokens.titlebarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('launcher_titlebar'),
      height: LauncherTokens.titlebarHeight,
      decoration: const BoxDecoration(
        color: LauncherTokens.bg0,
        border: Border(bottom: BorderSide(color: LauncherTokens.b1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _TopbarLeft(appTitle: appTitle, appSub: appSub)),
          const _VehicleStrip(),
          Expanded(
            child: _TopbarRight(onEnterFullscreen: onEnterFullscreen),
          ),
        ],
      ),
    );
  }
}

class _TopbarLeft extends StatelessWidget {
  const _TopbarLeft({required this.appTitle, this.appSub});

  final String appTitle;
  final String? appSub;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'AGL',
          key: Key('topbar_wordmark'),
          style: TextStyle(
            fontFamily: LauncherTokens.fontDisplay,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: LauncherTokens.t1,
            letterSpacing: 3.9,
          ),
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 20, color: LauncherTokens.b1),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appTitle,
                key: const Key('topbar_app_title'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: LauncherTokens.fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: LauncherTokens.t1,
                  height: 1.1,
                ),
              ),
              if (appSub != null)
                Text(
                  appSub!,
                  key: const Key('topbar_app_sub'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: LauncherTokens.fontBody,
                    fontSize: 11,
                    color: LauncherTokens.tHint,
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Static placeholder vehicle strip (Speed / Gear / Battery / Status).
/// Phase A uses dummy values; wiring to VSS / ROS is tracked separately.
class _VehicleStrip extends StatelessWidget {
  const _VehicleStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: LauncherTokens.b1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: const [
          _StripItem(label: 'Speed', value: '42', unit: 'km/h'),
          _StripSep(),
          _StripItem(label: 'Gear', value: 'D'),
          _StripSep(),
          _StripItem(label: 'Battery', value: '78', unit: '%'),
          _StripSep(),
          _StripItem(label: 'Status', value: 'Nominal', showDot: true),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.label,
    required this.value,
    this.unit,
    this.showDot = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: LauncherTokens.tHint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: LauncherTokens.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: LauncherTokens.t1,
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 1),
            Text(
              unit!,
              style: const TextStyle(
                fontSize: 10,
                color: LauncherTokens.tHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StripSep extends StatelessWidget {
  const _StripSep();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 14, color: LauncherTokens.b1);
}

class _TopbarRight extends StatefulWidget {
  const _TopbarRight({this.onEnterFullscreen});

  final VoidCallback? onEnterFullscreen;

  @override
  State<_TopbarRight> createState() => _TopbarRightState();
}

class _TopbarRightState extends State<_TopbarRight> {
  late Timer _clockTimer;
  late String _time;

  @override
  void initState() {
    super.initState();
    _time = _formatNow();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() => _time = _formatNow()),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatNow() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _time,
          key: const Key('topbar_time'),
          style: const TextStyle(
            fontFamily: LauncherTokens.fontBody,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: LauncherTokens.t1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        if (widget.onEnterFullscreen != null)
          _IconBtn(
            key: const Key('topbar_fullscreen_enter'),
            icon: Icons.fullscreen,
            semanticLabel: 'Fullscreen',
            onTap: widget.onEnterFullscreen!,
          ),
        const _IconBtn(icon: Icons.help_outline, semanticLabel: 'Help'),
        const _IconBtn(icon: Icons.language, semanticLabel: 'Language'),
        const _IconBtn(icon: Icons.person_outline, semanticLabel: 'Account'),
      ],
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 330),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover ? LauncherTokens.bg3 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 18,
            color: LauncherTokens.t1,
            semanticLabel: widget.semanticLabel,
          ),
        ),
      ),
    );
  }
}
