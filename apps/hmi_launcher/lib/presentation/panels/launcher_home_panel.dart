import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../theme/launcher_tokens.dart';

/// Tesla-style home panel.
///
/// Left column: greeting + responsive grid of category cards, each built
/// from a plugin manifest. Right column: an aside with Recent / Suggested
/// items and a "Try asking" hint block.
class LauncherHomePanel extends StatelessWidget {
  const LauncherHomePanel({
    super.key,
    required this.apps,
    required this.onAppLaunch,
    this.recent = const [],
    this.suggestions = const [],
    this.greeting = 'Good afternoon',
  });

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;
  final List<HomeAsideItem> recent;
  final List<HomeAsideItem> suggestions;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('launcher_home_panel'),
      color: LauncherTokens.bg0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _MainColumn(
            greeting: greeting,
            apps: apps,
            onAppLaunch: onAppLaunch,
          )),
          _Aside(recent: recent, suggestions: suggestions),
        ],
      ),
    );
  }
}

/// A single line in the home aside (Recent / Suggested sections).
class HomeAsideItem {
  const HomeAsideItem({
    required this.appId,
    required this.name,
    required this.meta,
    this.icon,
  });

  final String appId;
  final String name;
  final String meta;
  final IconData? icon;
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.greeting,
    required this.apps,
    required this.onAppLaunch,
  });

  final String greeting;
  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontFamily: LauncherTokens.fontDisplay,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: LauncherTokens.t1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${apps.length} apps installed · Ask AGL to open anything by name',
                style: const TextStyle(
                  fontSize: 14,
                  color: LauncherTokens.t3,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: apps.isEmpty
              ? const _EmptyState()
              : _HomeGrid(apps: apps, onAppLaunch: onAppLaunch),
        ),
      ],
    );
  }
}

class _HomeGrid extends StatelessWidget {
  const _HomeGrid({required this.apps, required this.onAppLaunch});

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1000
                ? 2
                : 3;
        return GridView.builder(
          key: const Key('launcher_home_grid'),
          padding: const EdgeInsets.fromLTRB(32, 0, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            // Card = 2:1 hero + ~60px foot → overall ~5:3 aspect.
            childAspectRatio: 5 / 3,
          ),
          itemCount: apps.length,
          itemBuilder: (_, i) => _CatCard(
            app: apps[i],
            onTap: () => onAppLaunch(apps[i]),
          ),
        );
      },
    );
  }
}

/// Tesla category card: 12px radius, 2:1 hero art, label overlay, and
/// a footer row with the tagline + "Open / Docs" sublinks.
class _CatCard extends StatefulWidget {
  const _CatCard({required this.app, required this.onTap});

  final AppManifest app;
  final VoidCallback onTap;

  @override
  State<_CatCard> createState() => _CatCardState();
}

class _CatCardState extends State<_CatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          key: Key('home_cat_card_${widget.app.id}'),
          duration: const Duration(milliseconds: 330),
          decoration: BoxDecoration(
            color: LauncherTokens.bg0,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover ? LauncherTokens.t1 : LauncherTokens.b1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _HeroArt(seed: widget.app.id, color: widget.app.color),
                    Positioned(
                      top: 14,
                      left: 16,
                      child: Text(
                        widget.app.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x33000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.app.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: LauncherTokens.t3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const _SubLink(label: 'Open'),
                    const SizedBox(width: 12),
                    const _SubLink(label: 'Docs'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stand-in hero art: soft two-stop gradient seeded by the manifest's color
/// plus a dark vignette so the white label stays readable. Phase A keeps
/// this lightweight; richer SVG art is Phase B.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.seed, required this.color});

  final String seed;
  final String color;

  @override
  Widget build(BuildContext context) {
    final base = _parseHex(color);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: 0.85),
            LauncherTokens.t1,
          ],
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    final s = hex.replaceAll('#', '');
    if (s.length != 6) return LauncherTokens.t1;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return LauncherTokens.t1;
    return Color(0xFF000000 | v);
  }
}

class _SubLink extends StatefulWidget {
  const _SubLink({required this.label});

  final String label;

  @override
  State<_SubLink> createState() => _SubLinkState();
}

class _SubLinkState extends State<_SubLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Text(
        widget.label,
        style: TextStyle(
          fontSize: 12,
          color: _hover ? LauncherTokens.t1 : LauncherTokens.t3,
          decoration:
              _hover ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside({required this.recent, required this.suggestions});

  final List<HomeAsideItem> recent;
  final List<HomeAsideItem> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(left: BorderSide(color: LauncherTokens.b1)),
      ),
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          if (recent.isNotEmpty) ...[
            const _AsideLabel('Recent'),
            for (final r in recent) _AsideRow(item: r),
            const SizedBox(height: 24),
          ],
          if (suggestions.isNotEmpty) ...[
            const _AsideLabel('Suggested'),
            for (final s in suggestions) _AsideRow(item: s),
            const SizedBox(height: 24),
          ],
          const _AsideLabel('Try asking'),
          const _AsideHint('"Open OTA monitor"'),
          const _AsideHint('"Show sensor health"'),
          const _AsideHint('"Visualise the route"'),
        ],
      ),
    );
  }
}

class _AsideLabel extends StatelessWidget {
  const _AsideLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: LauncherTokens.tHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AsideRow extends StatefulWidget {
  const _AsideRow({required this.item});

  final HomeAsideItem item;

  @override
  State<_AsideRow> createState() => _AsideRowState();
}

class _AsideRowState extends State<_AsideRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFEFEFEC) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon ?? Icons.circle_outlined,
                size: 14,
                color: LauncherTokens.t1,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LauncherTokens.t1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.item.meta,
                style: const TextStyle(
                  fontSize: 11,
                  color: LauncherTokens.tHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsideHint extends StatelessWidget {
  const _AsideHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: LauncherTokens.t3,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.apps_outlined, size: 32, color: LauncherTokens.tHint),
          SizedBox(height: 12),
          Text(
            'No plugins installed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: LauncherTokens.t1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Drop a manifest.json into the apps/ directory.',
            style: TextStyle(fontSize: 12, color: LauncherTokens.t3),
          ),
        ],
      ),
    );
  }
}
