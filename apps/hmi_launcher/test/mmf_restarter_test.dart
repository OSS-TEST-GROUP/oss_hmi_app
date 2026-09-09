import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/mmf_restarter.dart';

ProcessResult _ok([String out = '']) => ProcessResult(0, 0, out, '');
ProcessResult _fail([int code = 1]) => ProcessResult(0, code, '', 'boom');

/// inspect 응답 형식: `"<running>|<env...>"`
///
/// [dds] 는 DDS 평면 env 키를 고른다 — 보드에는 `MMF_DDS_DOMAIN_ID`(서비스별
/// override)와 `DDS_DOMAIN_ID`(정규 키)가 둘 다 나타날 수 있다.
String _inspect({
  bool running = true,
  int? dds,
  int? ros,
  String ddsKey = 'DDS_DOMAIN_ID',
}) {
  final env = [
    if (dds != null) '$ddsKey=$dds',
    if (ros != null) 'ROS_DOMAIN_ID=$ros',
    'HOME=/tmp',
  ].join(' ');
  return '$running|$env ';
}

void main() {
  group('MmfRestarter', () {
    test('두 평면 도메인이 모두 목표와 같으면 재시작한다', () async {
      final calls = <List<String>>[];
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async {
          calls.add([exe, ...args]);
          return args.first == 'inspect'
              ? _ok(_inspect(dds: 42, ros: 42))
              : _ok();
        },
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.restarted);
      expect(calls.last, ['docker', 'restart', 'oss-mmf-ext-agl']);
    });

    test('두 평면이 서로 다른 값이어도 각자 목표와 맞으면 재시작한다', () async {
      // 분리 운영(DDS 5 / ROS 42)이 정상 상태로 인식되어야 한다.
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => args.first == 'inspect'
            ? _ok(_inspect(dds: 5, ros: 42))
            : _ok(),
      );
      expect((await r.applyDomains(dds: 5, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.restarted);
    });

    test('DDS 평면만 달라도 needsRecreate', () async {
      // docker restart 는 생성 당시 env 를 재사용하므로 도메인을 바꿀 수 없다(실측).
      // 서비스만 끊기지 않도록 restart 를 시도조차 하지 않는다.
      final calls = <List<String>>[];
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async {
          calls.add([exe, ...args]);
          return _ok(_inspect(dds: 0, ros: 42));
        },
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.needsRecreate);
      expect(calls.map((c) => c[1]), isNot(contains('restart')));
    });

    test('ROS 평면만 달라도 needsRecreate', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => _ok(_inspect(dds: 42, ros: 7)),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.needsRecreate);
    });

    test('MMF_DDS_DOMAIN_ID(서비스별 override)가 DDS 평면으로 인정된다', () async {
      // MMF C++ 우선순위(MMF_DDS_DOMAIN_ID > DDS_DOMAIN_ID)와 같은 규칙이어야
      // 실제로 도는 도메인과 판정이 어긋나지 않는다.
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => args.first == 'inspect'
            ? _ok(_inspect(dds: 42, ros: 42, ddsKey: 'MMF_DDS_DOMAIN_ID'))
            : _ok(),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.restarted);
    });

    test('도메인 env 자체가 없으면 needsRecreate', () async {
      // 보드 실측: 옛 run 스크립트로 만든 ext-agl 은 env 가 없어 기본 도메인 0 으로 돈다.
      // 두 평면 분리 이전에 만들어진 컨테이너도 여기에 해당한다 → 재생성이 맞다.
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => _ok(_inspect()),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.needsRecreate);
    });

    test('없는 컨테이너는 skipped — 실패로 보고하지 않는다', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-core'], // 보통 다른 호스트에 있다
        runner: (exe, args) async => _fail(),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-core'],
          RestartOutcome.skipped);
    });

    test('정지 상태 컨테이너도 skipped', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async =>
            _ok(_inspect(running: false, dds: 42, ros: 42)),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.skipped);
    });

    test('restart 가 실패하면 failed', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => args.first == 'inspect'
            ? _ok(_inspect(dds: 42, ros: 42))
            : _fail(125),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.failed);
    });

    test('docker 를 못 쓰면 unavailable (개발 PC 등)', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => throw ProcessException(exe, args),
      );
      expect((await r.applyDomains(dds: 42, ros: 42))['oss-mmf-ext-agl'],
          RestartOutcome.unavailable);
    });

    test('env 파서는 두 평면 키를 각각 뽑는다', () {
      const env = 'PATH=/bin DDS_DOMAIN_ID=5 ROS_DOMAIN_ID=42 HOME=/tmp';
      expect(MmfRestarter.currentDdsDomain(env), 5);
      expect(MmfRestarter.currentRosDomain(env), 42);
      expect(MmfRestarter.currentDdsDomain('PATH=/bin'), isNull);
      expect(MmfRestarter.currentRosDomain('PATH=/bin'), isNull);
      // 숫자가 아니면 null — 조용히 0 으로 읽지 않는다.
      expect(MmfRestarter.currentRosDomain('ROS_DOMAIN_ID=abc'), isNull);
    });

    test('기본 대상은 같은 호스트의 ext-agl 뿐 + 재생성 안내 문구 제공', () {
      expect(MmfRestarter.kDefaultTargets, ['oss-mmf-ext-agl']);
      // 안내는 `oss-domain-apply` 를 가리켜야 한다. 예전 문구(run-ext-agl.sh)는
      // 81 의 ext-agl 하나만 다뤄서, 151 의 core/ext-ros2 가 옛 도메인에 남고
      // Autoware 가 그 값을 물려받아 재시작해도 도메인이 안 바뀌었다(실측 3회).
      expect(MmfRestarter.kRecreateHint, contains('oss-domain-apply'));
      expect(MmfRestarter.kRecreateHint, isNot(contains('run-ext-agl.sh')));
    });
  });
}
