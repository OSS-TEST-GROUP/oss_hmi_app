import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/dds_domain_store.dart';

void main() {
  group('DdsDomainStore', () {
    test('저장된 값이 없으면 기본 도메인 42', () {
      // 42 = 151 Autoware adsw 파티션 도메인. MMF 기본이 0 이던 동안
      // adsw_monitor 가 데이터를 못 받았던 실측 문제의 기본값 정정.
      expect(DdsDomainStore.inMemory().domain, kDefaultDdsDomain);
      expect(kDefaultDdsDomain, 42);
    });

    test('select() 이 값을 바꾸고 load() 후에도 유지된다', () async {
      final store = DdsDomainStore.inMemory();
      expect(await store.select(7), isTrue);
      expect(store.domain, 7);

      await store.load(); // 같은 백엔드에서 다시 읽어도 7
      expect(store.domain, 7);
    });

    test('select() 이 MMF 도메인 파일 형식(ROS_DOMAIN_ID=n)으로 기록한다', () async {
      final store = DdsDomainStore.inMemory();
      await store.select(13);

      final env = store.debugEnvSnapshot!();
      expect(env, isNotNull);
      // compose --env-file 과 shell source 양쪽이 파싱할 수 있는 최소 형식.
      expect(env, contains('ROS_DOMAIN_ID=13'));
      expect(store.lastEnvWriteOk, isTrue);
      expect(store.lastEnvError, isNull);
    });

    test('범위를 벗어난 도메인은 거부되고 값이 바뀌지 않는다', () async {
      final store = DdsDomainStore.inMemory(initialDomain: 42);
      expect(await store.select(-1), isFalse);
      expect(await store.select(kMaxDdsDomain + 1), isFalse);
      expect(store.domain, 42);
    });

    test('경계값 0 과 232 는 허용된다', () async {
      final store = DdsDomainStore.inMemory();
      expect(await store.select(kMinDdsDomain), isTrue);
      expect(store.domain, 0);
      expect(await store.select(kMaxDdsDomain), isTrue);
      expect(store.domain, 232);
    });

    test('손상된 설정 파일이면 기본값을 유지한다 (런처가 죽지 않음)', () async {
      final store = DdsDomainStore(
        readRaw: () async => '{ this is not json',
        writeRaw: (_) async {},
        writeEnv: (_) async {},
      );
      await store.load();
      expect(store.domain, kDefaultDdsDomain);
    });

    test('범위 밖 값이 저장돼 있으면 무시하고 기본값을 쓴다', () async {
      final store = DdsDomainStore(
        readRaw: () async => jsonEncode({'domain': 999}),
        writeRaw: (_) async {},
        writeEnv: (_) async {},
      );
      await store.load();
      expect(store.domain, kDefaultDdsDomain);
    });

    test('도메인 파일 쓰기 실패는 삼키지 않고 노출하되 설정은 저장된다', () async {
      var savedSetting = false;
      final store = DdsDomainStore(
        readRaw: () async => null,
        writeRaw: (_) async => savedSetting = true,
        writeEnv: (_) async => throw Exception('permission denied'),
      );
      expect(await store.select(21), isTrue); // 설정 저장은 성공
      expect(savedSetting, isTrue);
      expect(store.domain, 21);
      expect(store.lastEnvWriteOk, isFalse);
      expect(store.lastEnvError, contains('permission denied'));
    });

    test('select() 이 리스너에게 알린다 (UI 갱신)', () async {
      final store = DdsDomainStore.inMemory();
      var notified = 0;
      store.addListener(() => notified++);
      await store.select(5);
      expect(notified, 1);
    });
  });
}
