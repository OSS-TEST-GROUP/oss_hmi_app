// QA(docs/qa): LauncherConfig 유닛 테스트 (defaults / fromJson / 헬퍼 분기).
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/launcher_config.dart';

void main() {
  test('defaults', () {
    final c = LauncherConfig.defaults();
    expect(c.rosUrl.toString(), 'ws://localhost:9090');
    expect(c.statusTopic, '/app_status/hmi_launcher');
    expect(c.rosReconnectIntervalSec, 2);
    expect(c.heartbeatIntervalSec, 1);
    expect(c.otaTheme, 'light');
    expect(c.adswTheme, 'light');
    expect(c.diagTheme, 'light');
    expect(c.lfcTheme, 'light');
  });

  test('fromJson 전체 필드', () {
    final c = LauncherConfig.fromJson({
      'rosbridge': {'url': 'ws://1.2.3.4:9090'},
      'statusTopic': '/x',
      'rosReconnectIntervalSec': 5,
      'heartbeatIntervalSec': 3,
      'otaTheme': 'dark',
      'adswTheme': 'dark',
      'diagTheme': 'light',
      'lfcTheme': 'light',
    });
    expect(c.rosUrl.host, '1.2.3.4');
    expect(c.statusTopic, '/x');
    expect(c.rosReconnectIntervalSec, 5);
    expect(c.heartbeatIntervalSec, 3);
    expect(c.otaTheme, 'dark');
    expect(c.adswTheme, 'dark');
    expect(c.diagTheme, 'light');
    expect(c.lfcTheme, 'light');
  });

  test('fromJson 빈 맵 → 기본값 폴백', () {
    final c = LauncherConfig.fromJson({});
    expect(c.rosUrl.toString(), 'ws://localhost:9090');
    expect(c.statusTopic, '/app_status/hmi_launcher');
    expect(c.rosReconnectIntervalSec, 2);
    expect(c.otaTheme, 'light');
  });

  test('_asPositiveInt: 문자열 숫자', () {
    expect(
      LauncherConfig.fromJson({'rosReconnectIntervalSec': '7'}).rosReconnectIntervalSec,
      7,
    );
  });

  test('_asPositiveInt: num(double)', () {
    expect(
      LauncherConfig.fromJson({'heartbeatIntervalSec': 4.0}).heartbeatIntervalSec,
      4,
    );
  });

  test('_asPositiveInt: 잘못된/음수/0 → 폴백', () {
    expect(
      LauncherConfig.fromJson({'rosReconnectIntervalSec': 'bad'}).rosReconnectIntervalSec,
      2,
    );
    expect(
      LauncherConfig.fromJson({'rosReconnectIntervalSec': -1}).rosReconnectIntervalSec,
      2,
    );
    expect(
      LauncherConfig.fromJson({'heartbeatIntervalSec': 0}).heartbeatIntervalSec,
      1,
    );
  });

  // diag_monitor 는 adsw_monitor 에서 분리된 앱 → 분리 이전 설정 호환.
  test('diagTheme 미존재 시 adswTheme 을 물려받음 (분리 이전 설정 호환)', () {
    final c = LauncherConfig.fromJson({'adswTheme': 'dark'});
    expect(c.adswTheme, 'dark');
    expect(c.diagTheme, 'dark');
  });

  test('diagTheme 이 있으면 adswTheme 과 독립적으로 적용', () {
    final c = LauncherConfig.fromJson({
      'adswTheme': 'dark',
      'diagTheme': 'light',
    });
    expect(c.adswTheme, 'dark');
    expect(c.diagTheme, 'light');
  });

  test('둘 다 없으면 diagTheme 은 light', () {
    expect(LauncherConfig.fromJson({}).diagTheme, 'light');
  });

  test('_asThemeName: dark/그외/비문자 → light', () {
    expect(LauncherConfig.fromJson({'otaTheme': 'dark'}).otaTheme, 'dark');
    expect(LauncherConfig.fromJson({'otaTheme': 'weird'}).otaTheme, 'light');
    expect(LauncherConfig.fromJson({'otaTheme': 123}).otaTheme, 'light');
  });
}
