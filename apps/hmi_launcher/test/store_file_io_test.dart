// QA(docs/qa): DomainStore.file / AppVisibilityStore.file 팩토리(실 파일 I/O) 커버리지.
// 시스템 경로 오염을 막기 위해 storageDir/envFilePath 모두 임시 디렉토리로 지정한다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/domain_store.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('hmi_store_io_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('DomainStore.file', () {
    test('파일 없으면 로드는 기본값 유지', () async {
      final store = DomainStore.file(tmp.path,
          envFilePath: '${tmp.path}/domain.env');
      await store.load();
      expect(store.ddsDomain, kDefaultDdsDomain);
      expect(store.rosDomain, kDefaultRosDomain);
    });

    test('select → json + env 파일에 두 평면 기록, 재로드 시 반영', () async {
      final envPath = '${tmp.path}/domain.env';
      final s1 = DomainStore.file(tmp.path, envFilePath: envPath);
      await s1.load();
      final ok = await s1.select(dds: 5, ros: 42);
      expect(ok, isTrue);
      expect(s1.ddsDomain, 5);
      expect(s1.rosDomain, 42);
      expect(File('${tmp.path}/dds_domain.json').existsSync(), isTrue);
      final envText = File(envPath).readAsStringSync();
      expect(envText, contains('DDS_DOMAIN_ID=5'));
      expect(envText, contains('ROS_DOMAIN_ID=42'));

      final s2 = DomainStore.file(tmp.path, envFilePath: envPath);
      await s2.load();
      expect(s2.ddsDomain, 5);
      expect(s2.rosDomain, 42);
    });
  });

  group('AppVisibilityStore.file', () {
    test('파일 없으면 기본 숨김(ota_monitor/oss_launcher_bot) 적용', () async {
      final store = AppVisibilityStore.file(tmp.path);
      await store.load();
      expect(store.isEnabled('ota_monitor'), isFalse);
      expect(store.isEnabled('oss_launcher_bot'), isFalse);
      expect(store.isEnabled('adsw_monitor'), isTrue);
    });

    test('disable → 파일 기록, 재로드 시 persisted 상태가 기본값 대체', () async {
      final s1 = AppVisibilityStore.file(tmp.path);
      await s1.load();
      await s1.disable('adsw_monitor');
      await s1.enable('ota_monitor'); // 기본 숨김을 명시 노출로
      expect(File('${tmp.path}/app_visibility.json').existsSync(), isTrue);

      final s2 = AppVisibilityStore.file(tmp.path);
      await s2.load();
      expect(s2.isEnabled('adsw_monitor'), isFalse);
      expect(s2.isEnabled('ota_monitor'), isTrue); // persisted 가 기본값 이김
    });
  });
}
