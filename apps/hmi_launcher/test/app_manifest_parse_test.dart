// QA(docs/qa): AppManifest.parse / fromJson / isIncompatibleWith 미커버 분기.
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';

void main() {
  test('parse: 유효한 JSON → 필드 채움 + 기본값', () {
    final m = AppManifest.parse(
        '{"id":"a","name":"A","icon":"📦","version":"1.0.0","entry":"a/main.dart"}');
    expect(m.id, 'a');
    expect(m.category, 'misc');
    expect(m.color, '#64748B');
    expect(m.minLauncher, '0.0.0');
    expect(m.prompts, isEmpty);
  });

  test('parse: 잘못된 JSON 문자열 → ManifestFormatException', () {
    expect(() => AppManifest.parse('{not json',),
        throwsA(isA<ManifestFormatException>()));
  });

  test('parse: JSON 최상위가 객체가 아니면 예외', () {
    expect(() => AppManifest.parse('[1,2,3]', sourcePath: 'x.json'),
        throwsA(isA<ManifestFormatException>()));
  });

  test('fromJson: 필수 필드 누락 → 예외', () {
    expect(() => AppManifest.fromJson(const {'name': 'A'}),
        throwsA(isA<ManifestFormatException>()));
  });

  test('fromJson: prompts 가 리스트가 아니면 예외', () {
    expect(
      () => AppManifest.fromJson(const {
        'id': 'a', 'name': 'A', 'icon': '📦', 'version': '1.0.0',
        'entry': 'a/main.dart', 'prompts': 'not-a-list',
      }),
      throwsA(isA<ManifestFormatException>()),
    );
  });

  test('fromJson: prompts 리스트의 String 만 취함', () {
    final m = AppManifest.fromJson(const {
      'id': 'a', 'name': 'A', 'icon': '📦', 'version': '1.0.0',
      'entry': 'a/main.dart', 'prompts': ['x', 1, 'y', null],
    });
    expect(m.prompts, ['x', 'y']);
  });

  test('isIncompatibleWith: minLauncher 가 더 높으면 true', () {
    final m = AppManifest.fromJson(const {
      'id': 'a', 'name': 'A', 'icon': '📦', 'version': '1.0.0',
      'entry': 'a/main.dart', 'min_launcher': '5.0.0',
    });
    expect(m.isIncompatibleWith('4.0.0'), isTrue);
    expect(m.isIncompatibleWith('5.0.0'), isFalse);
    expect(m.isIncompatibleWith('6.0.0'), isFalse);
  });

  test('ManifestFormatException.toString', () {
    expect(ManifestFormatException('boom').toString(),
        contains('boom'));
  });

  test('toString 은 id + version', () {
    final m = AppManifest.fromJson(const {
      'id': 'a', 'name': 'A', 'icon': '📦', 'version': '2.1.0',
      'entry': 'a/main.dart',
    });
    expect(m.toString(), contains('a'));
    expect(m.toString(), contains('2.1.0'));
  });
}
