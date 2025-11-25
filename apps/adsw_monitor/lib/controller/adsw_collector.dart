import 'dart:io';

import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class AdswCollector extends GetxController {
  late Ros ros = Get.find<Ros>();
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<SubscribeHandler> handlerList = [];
  RxString isLaneDeparture = 'false'.obs;

  final Topic Function(Ros ros, String name, String type) topicFactory;

  AdswCollector({
    required this.topicFactory,
  }) {
    stdout.writeln('[Adsw collector] created.');
    handlerList = [
      handleVehicleStatus,
      handleCurrentVelocity,
      handleBattery,
      handleSensorCount,
      handleSensorData,
      handleObjectRecognition,
      handleTrafficLight,
      handlePlanningPath,
      handleLocalizationData,
      handleMapData,
      handleLaneDeparture,
    ];
  }

  void subscribeTopic(List<String> topics, List<String> types,
      List<SubscribeHandler> handlers) {
    for (int i = 0; i < topics.length; i++) {
      final topic = topicFactory(ros, topics[i], types[i]);
      topic.subscribe(handlers[i]);
    }
  }

  String _f2(num? v) => v == null ? '-' : v.toStringAsFixed(2);

  String _fmtVec3(Map? m) {
    if (m == null) return '-';
    final x = _f2(m['x'] as num?);
    final y = _f2(m['y'] as num?);
    final z = _f2(m['z'] as num?);
    return 'x:$x, y:$y, z:$z'; // 혹은 '($x, $y, $z)'
  }

  Future<void> handleVehicleStatus(Map<String, dynamic> msg) async {
    stdout.writeln('type: autoware_adapi_v1_msgs/VehicleStatus / topic: /api/vehicle/status \n msg: $msg');
    final gear = (msg['gear']?['status'] as num?)?.toInt();
    final ti = (msg['turn_indicators']?['status'] as num?)?.toInt();
    final hz = (msg['hazard_lights']?['status'] as num?)?.toInt();
    // final energy = (msg['energy_percentage'] as num?)?.toDouble();

    const gearText = {0: 'UNK', 1: 'N', 2: 'D', 3: 'R', 4: 'P', 5: 'L'};
    const tiText = {0: 'UNK', 1: 'OFF', 2: 'LEFT', 3: 'RIGHT'};
    const hzText = {0: 'UNK', 1: 'OFF', 2: 'ON'};

    topicData['Gear'] = gearText[gear] ?? '-';
    topicData['Turn indicator'] = tiText[ti] ?? '-';
    topicData['Hazard light'] = hzText[hz] ?? '-';
    // topicData['Energy %'] = energy?.toStringAsFixed(1);

    topicData['Steering tire angle'] = _f2(msg['steering_tire_angle']);
    //topicData['Bettery status'] = msg['energy_percentage'];
  }

  Future<void> handleCurrentVelocity(Map<String, dynamic> msg) async {
    stdout.writeln('type: autoware_vehicle_msgs/VelocityReport / topic: /vehicle/status/velocity_status \n msg: $msg');
    final vMs = msg['longitudinal_velocity'] as num?;
    final vKmh = vMs != null ? (vMs * 3.6).toStringAsFixed(2) : '-';
    topicData['Current velocity'] = vKmh;
    // final velocity = msg['longitudinal_velocity'];

    // if (velocity is num) {
    //   // 숫자면 소수점 2자리까지만 문자열로 저장
    //   topicData['Current velocity'] = velocity.toStringAsFixed(2);
    // } else {
    //   // 숫자가 아니면 그대로 저장
    //   topicData['Current velocity'] = velocity;
    // }
  }

  Future<void> handleBattery(Map<String, dynamic> msg) async {
    topicData['Battery status'] = msg['energy_level'];
  }

  Future<void> handleSensorCount(Map<String, dynamic> msg) async {
    topicData['Number of sensor'] = msg['data'];
  }

  Future<void> handleSensorData(Map<String, dynamic> msg) async {
    topicData['Imu Data - orientation_covariance'] =
        msg['orientation_covariance'];
  }

  Future<void> handleObjectRecognition(Map<String, dynamic> msg) async {
    stdout.writeln('type: autoware_adapi_v1_msgs/DynamicObjectArray / topic: /api/perception/objects \n msg: $msg');
    //topicData['Object recognition'] = msg['objects'];
    final List objs = (msg['objects'] as List?) ?? const [];

    if (objs.isEmpty) {
      topicData['Object recognition'] = '-';
      topicData['Object recognition count'] = 0;
      return;
    }

    const labelMap = {
      0: 'UNKNOWN',
      1: 'CAR',
      2: 'TRUCK',
      3: 'BUS',
      4: 'TRAILER',
      5: 'MOTORCYCLE',
      6: 'BICYCLE',
      7: 'PEDESTRIAN',
    };

    final List<String> lines = [];

    for (final o in objs) {
      if (o is! Map) {
        lines.add('UNKNOWN');
        continue;
      }

      final List klass = (o['classification'] as List?) ?? const [];

      if (klass.isEmpty) {
        lines.add('UNKNOWN');
        continue;
      }

      // 확률이 가장 높은 분류 하나 선택 (top-1)
      Map? best;
      double bestP = -1.0;
      for (final c in klass) {
        if (c is! Map) continue;
        final p = (c['probability'] as num?)?.toDouble() ?? 0.0;
        if (p > bestP) {
          bestP = p;
          best = c;
        }
      }

      final labelIdx = (best?['label'] as num?)?.toInt() ?? 0;
      final name = labelMap[labelIdx] ?? 'UNKNOWN';
      final prob = bestP.clamp(0.0, 1.0).toStringAsFixed(2);

      lines.add('$name ($prob)');
    }

    // 여러개면 줄바꿈으로 좌르륵
    topicData['Object recognition'] = lines.join('\n');
    topicData['Object recognition count'] = lines.length;
  }

  Future<void> handleTrafficLight(Map<String, dynamic> msg) async {
    topicData['Traffic light'] = msg;
  }

  Future<void> handlePlanningPath(Map<String, dynamic> msg) async {
    final List<dynamic> points = (msg['points'] as List?) ?? const [];

    if (points.isEmpty) {
      topicData['Planning path index'] = null;
      topicData['Planning path x'] = null;
      topicData['Planning path y'] = null;
      topicData['Planning path z'] = null;
      return;
    }

    // 1) is_final == true를 우선 사용
    int idx = points.indexWhere((p) => (p is Map && p['is_final'] == true));

    // 첫 포인트
    // int idx = 0.clamp(0, points.length - 1);

    // 2) is_final이 없다면 마지막 포인트 사용
    if (idx < 0) idx = points.length - 1;

    final Map<String, dynamic>? point = points[idx] as Map<String, dynamic>?;
    final Map<String, dynamic>? pose = point?['pose'] as Map<String, dynamic>?;
    final Map<String, dynamic>? pos =
        pose?['position'] as Map<String, dynamic>?;

    final double? x = (pos?['x'] as num?)?.toDouble();
    final double? y = (pos?['y'] as num?)?.toDouble();
    final double? z = (pos?['z'] as num?)?.toDouble();

    topicData['Planning path index'] = idx;
    topicData['Planning path x'] = x;
    topicData['Planning path y'] = y;
    topicData['Planning path z'] = z;
  }

  Future<void> handleLocalizationData(Map<String, dynamic> msg) async {
    stdout.writeln('type: / topic:  \n msg: ${msg}');
    // topicData['Localization pose x'] = msg['pose']['pose']['position']['x'];
    // topicData['Localization pose y'] = msg['pose']['pose']['position']['y'];
    // topicData['Localization pose z'] = msg['pose']['pose']['position']['z'];
    // topicData['Localization twist linear'] = msg['twist']['twist']['linear'];
    // topicData['Localization twist angular'] = msg['twist']['twist']['angular'];
    final pos = (msg['pose']?['pose']?['position']) as Map?;
    final lin = (msg['twist']?['twist']?['linear']) as Map?;
    final ang = (msg['twist']?['twist']?['angular']) as Map?;

    topicData['Localization pose x'] = _f2(pos?['x'] as num?);
    topicData['Localization pose y'] = _f2(pos?['y'] as num?);
    topicData['Localization pose z'] = _f2(pos?['z'] as num?);

    // 벡터는 x/y/z 각각 두 자리로 포맷해 문자열로 저장
    topicData['Localization twist linear'] = _fmtVec3(lin);
    topicData['Localization twist angular'] = _fmtVec3(ang);
  }

  Future<void> handleMapData(Map<String, dynamic> msg) async {
    topicData['pcd height'] = msg['height'];
    topicData['pcd width'] = msg['width'];
  }

  Future<void> handleLaneDeparture(Map<String, dynamic> msg) async {
    List statuses = msg['status'];

    for (var status in statuses) {
      if (status['name'] == 'lane_departure_checker: lane_departure') {
        String statusMsg = status['message'];
        List values = status['values'];

        String outOfLaneStr = values.firstWhere(
          (e) => e['key'] == 'is_out_of_lane',
          orElse: () => {'value': 'false'},
        )['value'];

        topicData['Lane departure'] = statusMsg;
        isLaneDeparture.value = outOfLaneStr;
      }
    }
  }
}
