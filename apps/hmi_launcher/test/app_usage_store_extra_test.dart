// QA(docs/qa): AppUsageStore — mostUsed 비교 분기 / suggestionCandidates 정렬 / recordOpen(_save).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';

void main() {
  late Directory tmp;
  late File file;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('hmi_usage_');
    file = File('${tmp.path}/usage.json');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('recordOpen 은 카운트 증가 + 파일 저장(_save)', () async {
    final s = AppUsageStore(file: file);
    await s.recordOpen('ota_monitor');
    await s.recordOpen('ota_monitor');
    expect(file.existsSync(), isTrue);
    final best = s.mostUsed({'ota_monitor'});
    expect(best?.appId, 'ota_monitor');
    expect(best!.openCount, 2);
  });

  test('mostUsed: 임계 미만(openCount<2 & foreground<60)은 제외', () async {
    final s = AppUsageStore(file: file);
    await s.recordOpen('rare'); // openCount=1, foreground=0 → 제외
    expect(s.mostUsed({'rare'}), isNull);
  });

  test('mostUsed: openCount 동점이면 foreground 시간으로 결정', () async {
    final s = AppUsageStore(file: file);
    await s.recordOpen('a');
    await s.recordOpen('a');
    await s.recordOpen('b');
    await s.recordOpen('b');
    await s.recordForegroundDuration('b', const Duration(seconds: 120));
    final best = s.mostUsed({'a', 'b'});
    expect(best?.appId, 'b'); // 동점 카운트, b 가 foreground 큼
  });

  test('suggestionCandidates: 카운트 내림차순 정렬 + 임계 필터', () async {
    final s = AppUsageStore(file: file);
    await s.recordOpen('low');
    await s.recordOpen('low'); // count 2
    await s.recordOpen('high');
    await s.recordOpen('high');
    await s.recordOpen('high'); // count 3
    await s.recordOpen('once'); // count 1 → 제외
    final cands = s.suggestionCandidates({'low', 'high', 'once'});
    expect(cands.map((e) => e.appId).toList(), ['high', 'low']);
  });

  test('저장 후 새 인스턴스가 load 로 복원', () async {
    final s1 = AppUsageStore(file: file);
    await s1.recordOpen('ota_monitor');
    await s1.recordOpen('ota_monitor');
    final s2 = AppUsageStore(file: file);
    await s2.load();
    expect(s2.mostUsed({'ota_monitor'})?.openCount, 2);
  });
}
