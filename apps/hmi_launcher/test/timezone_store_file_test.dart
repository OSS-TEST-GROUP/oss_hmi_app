// QA(docs/qa): TimezoneStore.file 팩토리(실 파일 I/O) + 손상 JSON 폴백.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/timezone_store.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('hmi_tz_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('file: 파일 없으면 기본(Asia/Seoul), select 시 기록 + 재로드 반영', () async {
    final s1 = TimezoneStore.file(tmp.path);
    await s1.load();
    expect(s1.selectedId, 'Asia/Seoul');
    await s1.select('Etc/UTC');
    expect(s1.selectedId, 'Etc/UTC');
    expect(File('${tmp.path}/timezone.json').existsSync(), isTrue);

    final s2 = TimezoneStore.file(tmp.path);
    await s2.load();
    expect(s2.selectedId, 'Etc/UTC');
  });

  test('손상된 JSON 로드 시 기본값으로 폴백', () async {
    final s = TimezoneStore(
      readRaw: () async => '{ this is not valid json',
      writeRaw: (_) async {},
    );
    await s.load();
    expect(s.selectedId, 'Asia/Seoul');
  });

  test('알 수 없는 timezone id 는 기본값으로 해석', () async {
    final s = TimezoneStore(
      readRaw: () async => '{"timezone":"Mars/Olympus"}',
      writeRaw: (_) async {},
    );
    await s.load();
    expect(s.selectedId, 'Asia/Seoul');
  });

  test('select: 유효 id 는 selected 옵션 오프셋 반영', () async {
    final s = TimezoneStore.inMemory();
    await s.select('America/New_York');
    expect(s.selected.offsetMinutes, -5 * 60);
  });
}
