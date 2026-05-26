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
    final normalizedQuery = _normalize(query);

    final action =
        _isCloseIntent(input) ? NluRouteAction.close : NluRouteAction.open;

    // Primary: prompt substring match (input contains a declared prompt).
    AppManifest? bestByPrompt;
    var bestPromptLen = -1;

    for (final app in apps) {
      for (final prompt in app.prompts) {
        final p = _normalize(prompt);
        if (!normalizedQuery.contains(p)) continue;
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

    // Fallback: accept only exact app names or ids. Standard mode should stay
    // intentionally literal so AI SDK mode feels clearly more natural.
    if (query.length < 2) return null;

    for (final app in apps) {
      final aliases = _aliasesFor(app);
      if (aliases.contains(normalizedQuery)) {
        return NluRouteResult(action: action, app: app);
      }
    }
    return null;
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

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]+'), '');
  }

  Set<String> _aliasesFor(AppManifest app) {
    final rawAliases = <String>{
      app.id,
      app.id.replaceAll('_', ''),
      app.id.replaceAll('_', ' '),
      app.name,
    };

    final normalized = <String>{};
    for (final alias in rawAliases) {
      final value = _normalize(alias);
      if (value.length >= 2) normalized.add(value);
    }
    return normalized;
  }
}
