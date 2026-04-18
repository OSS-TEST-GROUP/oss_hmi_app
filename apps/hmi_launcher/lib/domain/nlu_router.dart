import 'app_manifest.dart';

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
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return null;

    AppManifest? bestApp;
    var bestLen = -1;

    for (final app in apps) {
      for (final prompt in app.prompts) {
        final p = prompt.toLowerCase();
        if (!query.contains(p)) continue;
        final len = p.length;
        if (len > bestLen ||
            (len == bestLen && (bestApp == null || app.id.compareTo(bestApp.id) < 0))) {
          bestApp = app;
          bestLen = len;
        }
      }
    }
    return bestApp;
  }
}
