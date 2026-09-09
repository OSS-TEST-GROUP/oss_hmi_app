// QA(docs/qa): Rviz2Controller — ProcessRunner 주입 seam(TR-3)으로 docker/gRPC
// 성공 경로 + error 경로 유닛 검증. 실 docker/gRPC 데몬 없이 결정론적.
//
// seam: Rviz2Controller({required cfg, ProcessRunner? run}). 미주입 시 Process.run
// (프로덕션 동작 불변). 테스트는 fake 를 주입해 docker inspect/run/stop/logs 및
// grpcurl(exec) 응답을 흉내낸다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rviz2_panel/config/app_config.dart';
import 'package:rviz2_panel/controller/rviz2_controller.dart';
import 'package:rviz2_panel/data/rviz2_data.dart';

/// docker inspect 출력/exit 을 제어하는 fake ProcessRunner.
ProcessRunner fakeRunner({
  String inspectOut = 'running|||0',
  int inspectExit = 0,
  int runExit = 0,
  String logsOut = '[INFO] booting\n[ERROR] plugin load failed\nfailed to open\nplain stdout line',
  String logsErr = '[warn] deprecated flag\nbare stderr line',
  List<List<String>>? capture,
}) {
  return (String exe, List<String> args) async {
    capture?.add([exe, ...args]);
    if (args.contains('inspect')) {
      return ProcessResult(0, inspectExit, inspectOut, '');
    }
    if (args.contains('logs')) {
      return ProcessResult(0, 0, logsOut, logsErr);
    }
    // rm / run(create) / stop / exec(grpcurl) 등.
    if (args.isNotEmpty && args.first == 'run') {
      return ProcessResult(0, runExit, 'container_id_abc', '');
    }
    return ProcessResult(0, 0, '', '');
  };
}

void main() {
  group('refreshStatus (성공 경로 파싱)', () {
    test('running 출력 → running', () async {
      final c = Rviz2Controller(cfg: AppConfig.defaults(), run: fakeRunner());
      await c.refreshStatus();
      expect(c.container.value.state, ContainerState.running);
      c.onClose();
    });

    test('exited|||137 → exited + exitCode 137', () async {
      final c = Rviz2Controller(
          cfg: AppConfig.defaults(),
          run: fakeRunner(inspectOut: 'exited|||137'));
      await c.refreshStatus();
      expect(c.container.value.state, ContainerState.exited);
      expect(c.container.value.exitCode, 137);
      c.onClose();
    });

    test('created → created', () async {
      final c = Rviz2Controller(
          cfg: AppConfig.defaults(), run: fakeRunner(inspectOut: 'created|||0'));
      await c.refreshStatus();
      expect(c.container.value.state, ContainerState.created);
      c.onClose();
    });

    test('inspect exit!=0 → notInstalled', () async {
      final c = Rviz2Controller(
          cfg: AppConfig.defaults(), run: fakeRunner(inspectExit: 1));
      await c.refreshStatus();
      expect(c.container.value.state, ContainerState.notInstalled);
      c.onClose();
    });
  });

  test('start (성공): docker run + showRviz2(grpcurl) + tailLogs 경로', () async {
    final cap = <List<String>>[];
    final c = Rviz2Controller(
        cfg: AppConfig.defaults(), run: fakeRunner(capture: cap));
    await c.start(); // rect=null → _waitForRvizSurface 스킵, showRviz2+tailLogs 실행
    // docker rm/run + grpcurl exec + logs 호출이 기록됐다.
    final joined = cap.map((e) => e.join(' ')).join('\n');
    expect(joined, contains('run'));
    expect(joined, contains('grpcurl'));
    c.onClose();
  });

  test('start (실패): run exit!=0 → error 처리 + refreshStatus', () async {
    // run 실패 → 컨테이너 미기동 → 이후 refreshStatus 의 inspect 도 실패 상태.
    final c = Rviz2Controller(
        cfg: AppConfig.defaults(), run: fakeRunner(runExit: 1, inspectExit: 1));
    await c.start();
    expect(c.container.value.state, isNot(ContainerState.running));
    c.onClose();
  });

  test('stop (성공): docker stop 호출', () async {
    final cap = <List<String>>[];
    final c = Rviz2Controller(
        cfg: AppConfig.defaults(), run: fakeRunner(capture: cap));
    await c.stop();
    expect(cap.any((e) => e.contains('stop')), isTrue);
    c.onClose();
  });

  test('tailLogs: 초기 tail 파싱 → 레벨 분류(_levelFor 전 분기)', () async {
    final c = Rviz2Controller(
      cfg: AppConfig.defaults(),
      run: fakeRunner(
        // 40(에러): [error]/[fatal]/error:/failed/❌, 30(경고): [warn]/⚠️/태그없는stderr,
        // 20(정보): [info]/[debug]/[homebar]/▶/태그없는stdout. 빈 줄은 스킵.
        logsOut: '[INFO] boot\n[DEBUG] trace\n[homebar] ready\n▶ step\n'
            'plain stdout\n[ERROR] boom\n[FATAL] dead\nerror: bad\nfailed x\n❌ nope\n\n',
        logsErr: '[warn] dep\n⚠️ careful\nbare stderr\n',
      ),
    );
    await c.tailLogs();
    expect(c.logs, isNotEmpty);
    final levels = c.logs.map((l) => l.level).toSet();
    expect(levels.contains(40), isTrue); // 에러
    expect(levels.contains(30), isTrue); // 경고
    expect(levels.contains(20), isTrue); // 정보
    // 빈 줄은 추가되지 않는다(_appendLine 의 isEmpty 스킵).
    expect(c.logs.every((l) => l.msg.isNotEmpty), isTrue);
    c.onClose();
  });

  group('error 경로 (runner 미주입 = 실 Process.run, docker 부재)', () {
    test('refreshStatus → notInstalled', () async {
      final c = Rviz2Controller(cfg: AppConfig.defaults());
      await c.refreshStatus();
      expect(c.container.value.state, ContainerState.notInstalled);
      c.onClose();
    });

    test('applyConfig 는 cfg 교체', () {
      final c = Rviz2Controller(cfg: AppConfig.defaults());
      final next = AppConfig.defaults();
      c.applyConfig(next);
      expect(c.cfg, next);
      c.onClose();
    });
  });
}
