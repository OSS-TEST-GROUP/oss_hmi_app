// QA(docs/qa): rviz2_panel 데이터 모델 — ContainerState/ContainerInfo/LogLine.
import 'package:flutter_test/flutter_test.dart';
import 'package:rviz2_panel/data/rviz2_data.dart';

void main() {
  group('ContainerState.fromDockerStatus', () {
    test('docker status 문자열 매핑', () {
      expect(ContainerState.fromDockerStatus('running'), ContainerState.running);
      expect(ContainerState.fromDockerStatus('Running'), ContainerState.running);
      expect(ContainerState.fromDockerStatus('created'), ContainerState.created);
      expect(ContainerState.fromDockerStatus('exited'), ContainerState.exited);
      expect(ContainerState.fromDockerStatus('dead'), ContainerState.exited);
      expect(ContainerState.fromDockerStatus('removing'), ContainerState.exited);
      expect(ContainerState.fromDockerStatus('???'), ContainerState.notInstalled);
      expect(ContainerState.fromDockerStatus(null), ContainerState.notInstalled);
    });

    test('label 은 상태별 배지 문자열', () {
      expect(ContainerState.notInstalled.label, 'NOT INSTALLED');
      expect(ContainerState.created.label, 'CREATED');
      expect(ContainerState.running.label, 'RUNNING');
      expect(ContainerState.exited.label, 'STOPPED');
    });
  });

  test('ContainerInfo 기본값/필드', () {
    final info = ContainerInfo(name: 'rviz2');
    expect(info.name, 'rviz2');
    expect(info.state, ContainerState.notInstalled);
    expect(info.exitCode, isNull);
    info.state = ContainerState.running;
    info.exitCode = 0;
    expect(info.state, ContainerState.running);
  });

  test('LogLine.levelLabel 레벨별', () {
    final now = DateTime(2026);
    expect(LogLine(level: 40, name: 'r', msg: 'e', ts: now).levelLabel, 'ERR');
    expect(LogLine(level: 30, name: 'r', msg: 'w', ts: now).levelLabel, 'WARN');
    expect(LogLine(level: 20, name: 'r', msg: 'o', ts: now).levelLabel, 'OUT');
    expect(LogLine(level: 10, name: 'r', msg: 'd', ts: now).levelLabel, 'OUT');
  });
}
