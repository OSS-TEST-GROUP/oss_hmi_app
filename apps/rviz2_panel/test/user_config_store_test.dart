import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rviz2_panel/config/app_config.dart';
import 'package:rviz2_panel/config/user_config_store.dart';

/// 패널에서 바꾼 옵션이 **재기동 후에도 유지**되는지를 파일 왕복으로 검증한다.
/// 실제 저장 위치($XDG_CONFIG_HOME)는 보드 마운트에 달려 있으므로, 여기서는
/// 임시 디렉토리를 주입해 저장/로드/되돌리기 계약만 확인한다.
void main() {
  late Directory tmp;
  late UserConfigStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rviz2_panel_cfg');
    store = UserConfigStore(path: '${tmp.path}/rviz2_panel/config.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('저장본이 없으면 null (→ 호출자가 사이트 기본값을 쓴다)', () async {
    expect(await store.load(), isNull);
  });

  test('저장한 값이 그대로 다시 읽힌다', () async {
    final cfg = AppConfig.defaults().copyWith(
      image: 'registry.obigo.com/oss/rviz2-agl:base',
      containerName: 'rviz2_test',
      aglOutput: 'HDMI-A-1',
      pollIntervalSec: 7,
      dockerRunArgs: ['--net=host', '-e', 'FOO=1'],
      defaultDomainId: '7',
      rvizConfigPath: '/opt/x.rviz',
      rmwImplementation: 'rmw_cyclonedds_cpp',
      domainIdFromUser: true,
    );

    expect(await store.save(cfg), isNull); // 오류 없음

    final again = await store.load();
    expect(again, isNotNull);
    expect(again!.image, 'registry.obigo.com/oss/rviz2-agl:base');
    expect(again.containerName, 'rviz2_test');
    expect(again.aglOutput, 'HDMI-A-1');
    expect(again.pollIntervalSec, 7);
    expect(again.dockerRunArgs, ['--net=host', '-e', 'FOO=1']);
    expect(again.defaultDomainId, '7');
    expect(again.rvizConfigPath, '/opt/x.rviz');
    expect(again.rmwImplementation, 'rmw_cyclonedds_cpp');
  });

  test('저장된 도메인은 런처 Settings 로 덮이지 않는다', () async {
    await store.save(
        AppConfig.defaults().copyWith(defaultDomainId: '7', domainIdFromUser: true));
    final loaded = (await store.load())!;

    // 임베디드 패널이 런처 도메인(0)을 주입해도 사용자 저장값이 이긴다.
    expect(loaded.domainIdFromUser, isTrue);
    expect(loaded.withDomainId('0').defaultDomainId, '7');

    // 저장본이 아닌 설정은 종전대로 런처 값을 따른다.
    expect(AppConfig.defaults().withDomainId('0').defaultDomainId, '0');
  });

  test('되돌리기는 저장본을 .bak 으로 옮긴다 (삭제하지 않는다)', () async {
    await store.save(AppConfig.defaults().copyWith(image: 'x:1'));
    expect(await store.reset(), isNull);

    expect(await store.load(), isNull); // 다음 로드는 사이트 기본값으로
    expect(await File('${store.path}.bak').exists(), isTrue);
  });

  test('깨진 파일은 null 로 떨어진다 (기본값 폴백)', () async {
    final f = File(store.path);
    await f.parent.create(recursive: true);
    await f.writeAsString('{깨진 json');
    expect(await store.load(), isNull);
  });

  test('저장 형식은 사람이 고칠 수 있는 들여쓴 JSON', () async {
    await store.save(AppConfig.defaults());
    final raw = await File(store.path).readAsString();
    expect(raw, contains('\n  "image"'));
    expect(jsonDecode(raw), isA<Map<String, dynamic>>());
  });
}
