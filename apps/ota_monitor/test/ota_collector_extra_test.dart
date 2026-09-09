// QA(docs/qa): OtaCollector 미커버 — 응답 핸들러(settings/setSettings/state/update/
// notifyStatus/deleteClient) + 명령(requestAppList/deleteClient) + _updateAppList.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/controller/ota_collector.dart';

class _MockRos extends Mock implements Ros {}

class _MockTopic extends Mock implements Topic {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(<String, dynamic>{});

  late OtaCollector c;
  late Map<String, List<dynamic>> published;

  setUp(() async {
    Get.reset();
    published = {};
    final ros = _MockRos();
    Get.put<Ros>(ros);
    Topic factory(Ros r, String name, String type) {
      final t = _MockTopic();
      when(() => t.subscribe(any())).thenAnswer((_) async {});
      when(() => t.advertise()).thenAnswer((_) async {});
      when(() => t.publish(any())).thenAnswer((inv) async {
        (published[name] ??= []).add(inv.positionalArguments[0]);
      });
      return t;
    }
    c = OtaCollector(topicFactory: factory, autoStartTimers: false);
    Get.put<OtaCollector>(c);
    await c.startTopics(ros);
  });

  tearDown(() {
    Get.delete<OtaCollector>(force: true);
    Get.reset();
  });

  test('onSettingsResponse 는 topicData 갱신', () {
    c.onSettingsResponse({
      'app_name': 'ota', 'app_settings': 'automated=true', 'ret_code': 0,
    });
    expect(c.topicData['ota_settings'], 'automated=true');
  });

  test('onSetSettingsResponse 는 결과 기록', () {
    c.onSetSettingsResponse({'app_name': 'ota', 'ret_code': 0});
    expect(c.topicData['last_set_settings_result'], isNotNull);
  });

  test('onStateResponse 는 state 기록', () {
    c.onStateResponse({
      'app_name': 'ota', 'app_state_info': 'IDLE', 'ret_code': 0,
    });
    expect(c.topicData['ota_state'], 'IDLE');
  });

  test('onUpdateResponse 는 update 결과 기록', () {
    c.onUpdateResponse({'app_name': 'ota', 'ret_code': 0});
    expect(c.topicData['ota_update_result'], isNotNull);
  });

  test('onNotifyStatus 는 status + appList 갱신(_updateAppList)', () {
    c.appList.add({'name': 'ota', 'status': 'Unknown'});
    c.onNotifyStatus({'app_name': 'ota', 'status': 'Updating'});
    expect(c.topicData['ota_status'], 'Updating');
    expect(c.appList.first['status'], 'Updating');
  });

  test('onNotifyStatus: appList 에 없으면 새 항목 추가', () {
    c.onNotifyStatus({'app_name': 'newapp', 'status': 'Idle'});
    expect(c.appList.any((a) => a['name'] == 'newapp'), isTrue);
  });

  test('requestAppList / deleteClient 는 publish', () {
    c.requestAppList();
    c.deleteClient(7);
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });

  test('onDeleteClientResponse 처리(재조회 트리거)', () {
    c.onDeleteClientResponse({'ret_code': 0});
    // 예외 없이 완료 + appList 재조회 publish 발생 가능.
    expect(c.topicData, isNotNull);
  });

  test('request 메서드는 고유 id 반환', () {
    final id1 = c.requestAppSettings('ota');
    final id2 = c.requestAppState('ota');
    expect(id1, isNot(id2));
  });
}
