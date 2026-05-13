import 'app_manifest.dart';

enum NluRouteAction { open, close }

class NluRouteResult {
  const NluRouteResult({required this.action, required this.app});

  final NluRouteAction action;
  final AppManifest app;
}

/// Resolves free-form user input to a target [AppManifest] using nothing
/// more than case-insensitive substring matching against `manifest.prompts`.
///
/// This is the MVP stub for F-02. When the launcher moves to an LLM-backed
/// NLU later (Phase 2), the router interface should stay the same: given
/// text in, return a manifest (or null) out.
///
/// Matching rules:
///   - Input is trimmed; empty or whitespace-only input returns null.
///   - Comparison is case-insensitive.
///   - If multiple prompts across apps match, the app whose matching prompt
///     is the LONGEST wins. Longer phrases are more specific and therefore
///     a better intent signal than short ones.
///   - Ties (same prompt length) are broken by manifest `id` lexicographic
///     order so the resolution is deterministic.
class NluRouter {
  NluRouter(this.apps);

  final List<AppManifest> apps;

  AppManifest? resolve(String input) {
    return resolveIntent(input)?.app;
  }

  NluRouteResult? resolveIntent(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return null;

    final action =
        _isCloseIntent(input) ? NluRouteAction.close : NluRouteAction.open;

    // Primary: prompt substring match (input contains a declared prompt).
    AppManifest? bestByPrompt;
    var bestPromptLen = -1;

    for (final app in apps) {
      for (final prompt in app.prompts) {
        final p = prompt.toLowerCase();
        if (!query.contains(p)) continue;
        final len = p.length;
        if (len > bestPromptLen ||
            (len == bestPromptLen &&
                (bestByPrompt == null ||
                    app.id.compareTo(bestByPrompt.id) < 0))) {
          bestByPrompt = app;
          bestPromptLen = len;
        }
      }
    }
    if (bestByPrompt != null) {
      return NluRouteResult(action: action, app: bestByPrompt);
    }

    // Fallback: match against the manifest's display name or id.
    // Either direction is accepted: a short query like "ota" opens the
    // app whose name/id contains it, and a longer sentence like
    // "launch ota_monitor now" still matches on id substring.
    // Single-char queries are ignored to avoid false positives.
    if (query.length < 2) return null;

    AppManifest? bestByName;
    var bestNameScore = -1;
    for (final app in apps) {
      final name = app.name.toLowerCase();
      final id = app.id.toLowerCase();
      var score = -1;
      if (name.contains(query) || query.contains(name)) {
        score = name.length;
      }
      if (id.contains(query) || query.contains(id)) {
        final s = id.length;
        if (s > score) score = s;
      }
      if (score < 0) continue;
      if (score > bestNameScore ||
          (score == bestNameScore &&
              (bestByName == null || app.id.compareTo(bestByName.id) < 0))) {
        bestByName = app;
        bestNameScore = score;
      }
    }
    if (bestByName == null) return null;
    return NluRouteResult(action: action, app: bestByName);
  }

  bool _isCloseIntent(String input) {
    final query = input.trim().toLowerCase();
    return query.contains('close') ||
        query.contains('exit') ||
        query.contains('quit') ||
        query.contains('종료') ||
        query.contains('닫') ||
        query.contains('꺼') ||
        query.contains('나가') ||
        query.contains('뒤로');
  }
}
