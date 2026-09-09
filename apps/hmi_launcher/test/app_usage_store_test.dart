// QA(docs/qa): AppUsageStore / AppUsageStats 유닛 테스트 (순수 로직 + 주입 File).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';

void main() {
  group('AppUsageStats', () {
    test('toJson/fromJson 왕복', () {
      final s = AppUsageStats(
        appId: 'a', openCount: 3,
        lastOpenedAt: DateTime(2026, 1, 1), totalForegroundSeconds: 120,
      );
      final r = AppUsageStats.fromJson('a', s.toJson());
      expect(r, isNotNull);
      expect(r!.openCount, 3);
      expect(r.totalForegroundSeconds, 120);
    });

    test('non-map 은 null', () {
      expect(AppUsageStats.fromJson('a', 'x'), isNull);
    });

    test('openCount<=0 은 null', () {
      expect(
        AppUsageStats.fromJson('a', {
          'openCount': 0,
          'lastOpenedAt': DateTime(2026).toIso8601String(),
        }),
        isNull,
      );
    });

    test('잘못된 날짜는 null', () {
      expect(
        AppUsageStats.fromJson('a', {'openCount': 1, 'lastOpenedAt': 'notadate'}),
        isNull,
      );
    });

    test('totalForegroundSeconds 누락 시 0', () {
      final r = AppUsageStats.fromJson('a', {
        'openCount': 1,
        'lastOpenedAt': DateTime(2026).toIso8601String(),
      });
      expect(r!.totalForegroundSeconds, 0);
    });
  });

  group('AppUsageStore', () {
    late Directory dir;
    late File f;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('usage');
      f = File('${dir.path}/u.json');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('없는 파일 load 는 빈 상태', () async {
      final s = AppUsageStore(file: f);
      await s.load();
      expect(s.mostUsed({'a'}), isNull);
    });

    test('recordOpen 증가 + 영속 + 재로드', () async {
      final s = AppUsageStore(file: f);
      await s.recordOpen('a');
      await s.recordOpen('a');
      expect(f.existsSync(), isTrue);
      final s2 = AppUsageStore(file: f);
      await s2.load();
      expect(s2.mostUsed({'a'})?.openCount, 2);
    });

    test('recordForegroundDuration 누적 (0/미등록 무시)', () async {
      final s = AppUsageStore(file: f);
      await s.recordOpen('a');
      await s.recordForegroundDuration('a', const Duration(seconds: 90));
      await s.recordForegroundDuration('a', const Duration(seconds: 0));
      await s.recordForegroundDuration('unknown', const Duration(seconds: 10));
      await s.recordOpen('a'); // openCount 2 → mostUsed 대상
      expect(s.mostUsed({'a'})?.totalForegroundSeconds, 90);
    });

    test('깨진 파일 load 는 안전', () async {
      f.writeAsStringSync('<<bad json>>');
      final s = AppUsageStore(file: f);
      await s.load();
      expect(s.mostUsed({'a'}), isNull);
    });

    test('mostUsed threshold 적용', () async {
      final s = AppUsageStore(file: f);
      await s.recordOpen('a'); // 1회 → 제외
      expect(s.mostUsed({'a'}), isNull);
      await s.recordOpen('a'); // 2회 → 포함
      expect(s.mostUsed({'a'})?.appId, 'a');
    });

    test('suggestionCandidates 정렬 (openCount 우선)', () async {
      final s = AppUsageStore(file: f);
      await s.recordOpen('a');
      await s.recordOpen('a');
      await s.recordOpen('b');
      await s.recordOpen('b');
      await s.recordOpen('b');
      final c = s.suggestionCandidates({'a', 'b'});
      expect(c.first.appId, 'b');
    });

    test('mostUsed 는 유효하지 않은 appId 무시', () async {
      final s = AppUsageStore(file: f);
      await s.recordOpen('a');
      await s.recordOpen('a');
      expect(s.mostUsed({'other'}), isNull);
    });
  });
}
