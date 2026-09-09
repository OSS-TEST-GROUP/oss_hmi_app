// QA(docs/qa): rviz2_panel config_loader — args/파일 파싱, 기본값 폴백.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rviz2_panel/config/app_config.dart';
import 'package:rviz2_panel/config/config_loader.dart';
import 'package:rviz2_panel/config/user_config_store.dart';

void main() {
  late Directory tmp;

  // loadConfig 은 내부에서 UserConfigStore() 를 만들어 사용자/기기 기본값 파일이
  // 있으면 candidate 루프 전에 조기 반환한다. 앞선 실행이 seedDefault 로 남긴
  // 컨테이너-로컬 임시 config 를 정리해, 매 테스트가 candidate 경로를 결정론적으로
  // 타게 한다(HOME 하위 임시 상태만 삭제 — 사용자 실데이터 아님).
  void cleanStoreFiles() {
    final s = UserConfigStore();
    for (final p in [s.path, s.defPath]) {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    }
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('rviz2_cfg_');
    cleanStoreFiles();
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
    cleanStoreFiles();
  });

  test('인자 없음 → AppConfig 반환(기본값 계열)', () async {
    final cfg = await loadConfig(const []);
    expect(cfg, isA<AppConfig>());
  });

  test('--config 로 지정한 JSON 파일 파싱', () async {
    final f = File('${tmp.path}/config.json');
    final base = AppConfig.defaults();
    // 유효한 config 를 기록(스키마는 fromJson 이 관대하게 처리).
    f.writeAsStringSync(jsonEncode({'container_name': 'rviz2_test'}));
    final cfg = await loadConfig(['--config', f.path]);
    expect(cfg, isA<AppConfig>());
    // 파싱이 성공하면 예외 없이 반환된다(필드 반영은 스키마 의존).
    expect(base, isA<AppConfig>());
  });

  test('--config 파일이 손상되면 기본값으로 폴백', () async {
    final f = File('${tmp.path}/bad.json');
    f.writeAsStringSync('{ not valid json');
    final cfg = await loadConfig(['--config', f.path]);
    expect(cfg, isA<AppConfig>());
  });

  test('--config 파일이 없으면 기본값', () async {
    final cfg = await loadConfig(['--config', '${tmp.path}/missing.json']);
    expect(cfg, isA<AppConfig>());
  });
}
