import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/domain_store.dart';

void main() {
  group('DomainStore', () {
    test('저장된 값이 없으면 두 평면 모두 기본 도메인 42', () {
      // 42 = 151 Autoware adsw 파티션 도메인. MMF 기본이 0 이던 동안
      // adsw_monitor 가 데이터를 못 받았던 실측 문제의 기본값 정정.
      final store = DomainStore.inMemory();
      expect(store.ddsDomain, kDefaultDdsDomain);
      expect(store.rosDomain, kDefaultRosDomain);
      expect(kDefaultDdsDomain, 42);
      // 기본이 같으므로 분리 전까지는 오늘까지의 동작과 동일하다.
      expect(store.isSplit, isFalse);
    });

    test('select() 이 두 평면을 각각 바꾸고 load() 후에도 유지된다', () async {
      final store = DomainStore.inMemory();
      expect(await store.select(dds: 7, ros: 8), isTrue);
      expect(store.ddsDomain, 7);
      expect(store.rosDomain, 8);
      expect(store.isSplit, isTrue);

      await store.load(); // 같은 백엔드에서 다시 읽어도 7/8
      expect(store.ddsDomain, 7);
      expect(store.rosDomain, 8);
    });

    test('한쪽만 주면 다른 평면은 그대로 유지된다', () async {
      final store = DomainStore.inMemory();
      expect(await store.select(dds: 11), isTrue);
      expect(store.ddsDomain, 11);
      expect(store.rosDomain, kDefaultRosDomain);

      expect(await store.select(ros: 12), isTrue);
      expect(store.ddsDomain, 11); // 유지
      expect(store.rosDomain, 12);
    });

    test('select() 이 도메인 파일에 두 키를 모두 기록한다', () async {
      final store = DomainStore.inMemory();
      await store.select(dds: 13, ros: 14);

      final env = store.debugEnvSnapshot!();
      expect(env, isNotNull);
      // compose --env-file 과 shell source 양쪽이 파싱할 수 있는 최소 형식.
      expect(env, contains('DDS_DOMAIN_ID=13'));
      expect(env, contains('ROS_DOMAIN_ID=14'));
      expect(store.lastEnvWriteOk, isTrue);
      expect(store.lastEnvError, isNull);
    });

    test('범위를 벗어난 도메인은 거부되고 두 값 모두 바뀌지 않는다', () async {
      final store = DomainStore.inMemory(initialDdsDomain: 42, initialRosDomain: 42);
      expect(await store.select(dds: -1), isFalse);
      expect(await store.select(ros: kMaxDomainId + 1), isFalse);
      // 한쪽만 잘못돼도 절반 적용을 만들지 않는다.
      expect(await store.select(dds: 9, ros: 999), isFalse);
      expect(store.ddsDomain, 42);
      expect(store.rosDomain, 42);
    });

    test('경계값 0 과 232 는 허용된다', () async {
      final store = DomainStore.inMemory();
      expect(await store.select(dds: kMinDomainId, ros: kMinDomainId), isTrue);
      expect(store.ddsDomain, 0);
      expect(await store.select(dds: kMaxDomainId, ros: kMaxDomainId), isTrue);
      expect(store.ddsDomain, 232);
      expect(store.rosDomain, 232);
    });

    test('손상된 설정 파일이면 기본값을 유지한다 (런처가 죽지 않음)', () async {
      final store = DomainStore(
        readRaw: () async => '{ this is not json',
        writeRaw: (_) async {},
        writeEnv: (_) async {},
      );
      await store.load();
      expect(store.ddsDomain, kDefaultDdsDomain);
      expect(store.rosDomain, kDefaultRosDomain);
    });

    test('범위 밖 값이 저장돼 있으면 무시하고 기본값을 쓴다', () async {
      final store = DomainStore(
        readRaw: () async => jsonEncode({'dds_domain': 999, 'ros_domain': -3}),
        writeRaw: (_) async {},
        writeEnv: (_) async {},
      );
      await store.load();
      expect(store.ddsDomain, kDefaultDdsDomain);
      expect(store.rosDomain, kDefaultRosDomain);
    });

    test('구 포맷({"domain": n})은 두 평면 모두 n 으로 읽는다 (업그레이드 무회귀)', () async {
      final store = DomainStore(
        readRaw: () async => jsonEncode({'domain': 17}),
        writeRaw: (_) async {},
        writeEnv: (_) async {},
      );
      await store.load();
      expect(store.ddsDomain, 17);
      expect(store.rosDomain, 17);
      expect(store.isSplit, isFalse);
    });

    test('JSON 이 Map 이 아니면 기본값을 유지한다', () async {
      final store = DomainStore(
        readRaw: () async => jsonEncode([1, 2, 3]),
        writeRaw: (_) async {},
        writeEnv: (_) async {},
      );
      await store.load();
      expect(store.ddsDomain, kDefaultDdsDomain);
    });

    test('도메인 파일 쓰기 실패는 삼키지 않고 노출하되 설정은 저장된다', () async {
      var savedSetting = false;
      final store = DomainStore(
        readRaw: () async => null,
        writeRaw: (_) async => savedSetting = true,
        writeEnv: (_) async => throw Exception('permission denied'),
      );
      expect(await store.select(dds: 21, ros: 21), isTrue); // 설정 저장은 성공
      expect(savedSetting, isTrue);
      expect(store.ddsDomain, 21);
      expect(store.lastEnvWriteOk, isFalse);
      expect(store.lastEnvError, contains('permission denied'));
    });

    test('select() 이 리스너에게 알린다 (UI 갱신)', () async {
      final store = DomainStore.inMemory();
      var notified = 0;
      store.addListener(() => notified++);
      await store.select(dds: 5, ros: 5);
      expect(notified, 1);
    });

    test('isValidDomainId 는 두 평면 공통 규칙을 판정한다', () {
      expect(DomainStore.isValidDomainId(null), isFalse);
      expect(DomainStore.isValidDomainId(-1), isFalse);
      expect(DomainStore.isValidDomainId(0), isTrue);
      expect(DomainStore.isValidDomainId(232), isTrue);
      expect(DomainStore.isValidDomainId(233), isFalse);
    });
  });
}
