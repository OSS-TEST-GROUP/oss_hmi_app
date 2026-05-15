import 'package:flutter/widgets.dart';

/// InheritedWidget that propagates app accent color throughout the widget tree.
/// This enables surgical rebuilds when the selected app changes, affecting only
/// widgets that depend on the accent color (sidebar glow, statusbar border, etc).
class AppAccentScope extends InheritedWidget {
  const AppAccentScope({
    super.key,
    required this.accentColor,
    required super.child,
  });

  final Color accentColor;

  /// Returns the accent color from the nearest AppAccentScope.
  /// Throws if no AppAccentScope is found in the widget tree.
  static Color of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppAccentScope>();
    assert(scope != null, 'No AppAccentScope found in context');
    return scope!.accentColor;
  }

  /// Returns the accent color from the nearest AppAccentScope, or null if not found.
  static Color? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppAccentScope>()
        ?.accentColor;
  }

  @override
  bool updateShouldNotify(AppAccentScope oldWidget) =>
      accentColor != oldWidget.accentColor;
}
