import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/mmf_restarter.dart';

ProcessResult _ok([String out = '']) => ProcessResult(0, 0, out, '');
ProcessResult _fail([int code = 1]) => ProcessResult(0, code, '', 'boom');

/// inspect 응답 형식: "<running>|<env...>"
String _inspect({bool running = true, int? domain}) =>
    '$running|${domain == null ? '' : 'ROS_DOMAIN_ID=$domain '}HOME=/tmp ';

void main() {
  group('MmfRestarter', () {
    test('컨테이너 도메인이 목표와 같으면 재시작한다', () async {
      final calls = <List<String>>[];
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async {
          calls.add([exe, ...args]);
          return args.first == 'inspect' ? _ok(_inspect(domain: 42)) : _ok();
        },
      );
      expect((await r.applyDomain(42))['oss-mmf-ext-agl'],
          RestartOutcome.restarted);
      expect(calls.last, ['docker', 'restart', 'oss-mmf-ext-agl']);
    });

    test('도메인이 다르면 재시작하지 않고 needsRecreate 를 보고한다', () async {
      // docker restart 는 생성 당시 env 를 재사용하므로 도메인을 바꿀 수 없다(실측).
      // 서비스만 끊기지 않도록 restart 를 시도조차 하지 않는다.
      final calls = <List<String>>[];
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async {
          calls.add([exe, ...args]);
          return _ok(_inspect(domain: 0));
        },
      );
      expect((await r.applyDomain(42))['oss-mmf-ext-agl'],
          RestartOutcome.needsRecreate);
      expect(calls.map((c) => c[1]), isNot(contains('restart')));
    });

    test('ROS_DOMAIN_ID env 자체가 없으면 needsRecreate', () async {
      // 보드 실측: 옛 run 스크립트로 만든 ext-agl 은 env 가 없어 기본 도메인 0 으로 돈다.
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => _ok(_inspect()),
      );
      expect((await r.applyDomain(42))['oss-mmf-ext-agl'],
          RestartOutcome.needsRecreate);
    });

    test('없는 컨테이너는 skipped — 실패로 보고하지 않는다', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-core'], // 보통 다른 호스트에 있다
        runner: (exe, args) async => _fail(),
      );
      expect((await r.applyDomain(42))['oss-mmf-core'], RestartOutcome.skipped);
    });

    test('정지 상태 컨테이너도 skipped', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => _ok(_inspect(running: false, domain: 42)),
      );
      expect((await r.applyDomain(42))['oss-mmf-ext-agl'],
          RestartOutcome.skipped);
    });

    test('restart 가 실패하면 failed', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async =>
            args.first == 'inspect' ? _ok(_inspect(domain: 42)) : _fail(125),
      );
      expect((await r.applyDomain(42))['oss-mmf-ext-agl'],
          RestartOutcome.failed);
    });

    test('docker 를 못 쓰면 unavailable (개발 PC 등)', () async {
      final r = MmfRestarter(
        containers: ['oss-mmf-ext-agl'],
        runner: (exe, args) async => throw ProcessException(exe, args),
      );
      expect((await r.applyDomain(42))['oss-mmf-ext-agl'],
          RestartOutcome.unavailable);
    });

    test('기본 대상은 같은 호스트의 ext-agl 뿐 + 재생성 안내 문구 제공', () {
      expect(MmfRestarter.kDefaultTargets, ['oss-mmf-ext-agl']);
      expect(MmfRestarter.kRecreateHint, contains('run-ext-agl.sh'));
    });
  });
}
