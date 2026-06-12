// Unit tests for GemmaModelMetrics.tokensPerSecond — the pure derivation
// surfaced in the metrics dialog. Guards the divide-by-zero / empty-run
// edge cases.

import 'package:flutter_test/flutter_test.dart';
import 'package:oss_launcher_bot/services/gemma_chatbot_service.dart';

void main() {
  group('GemmaModelMetrics.tokensPerSecond', () {
    test('computes tokens / (ms/1000)', () {
      const m = GemmaModelMetrics(
        tokens: 120,
        generationTimeMs: 2000,
        firstTokenTimeMs: 100,
      );
      // 120 tokens over 2.0 s → 60 tok/s
      expect(m.tokensPerSecond, closeTo(60.0, 1e-9));
    });

    test('returns 0 when there are no tokens', () {
      const m = GemmaModelMetrics(
        tokens: 0,
        generationTimeMs: 1000,
        firstTokenTimeMs: 0,
      );
      expect(m.tokensPerSecond, 0);
    });

    test('returns 0 when generation time is non-positive (no divide-by-zero)', () {
      const m = GemmaModelMetrics(
        tokens: 50,
        generationTimeMs: 0,
        firstTokenTimeMs: 0,
      );
      expect(m.tokensPerSecond, 0);
    });

    test('handles negative guards defensively', () {
      const m = GemmaModelMetrics(
        tokens: -5,
        generationTimeMs: -10,
        firstTokenTimeMs: 0,
      );
      expect(m.tokensPerSecond, 0);
    });
  });
}
