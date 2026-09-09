import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/grpc/grpc_client.dart';
import 'package:vehicle_data_app/pages/can_data_page.dart';
import 'package:vehicle_data_app/pages/obd_data_page.dart';
import 'package:vehicle_data_app/pages/receiver_page.dart';
import 'package:vehicle_data_app/src/generated/VISSv3.0.pb.dart';
import 'package:vehicle_data_app/services/data_cache.dart';

void main() {
  group('VehicleDataApp Pages Tests', () {
    testWidgets('CanDataPage renders empty state and data state', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      DataCache.instance.update({});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanDataPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CSV를 불러와 전송을 시작하세요'), findsOneWidget);

      DataCache.instance.update({
        'VehicleModelID': 'KONA',
        'UserID': 'driver1',
        'Timestamp': '2026-08-24T18:00:00Z',
        'Vehicle.Speed': 75.5,
        'Vehicle.Powertrain.CombustionEngine.Speed': 2200,
        'Vehicle.CurrentLocation.Latitude': 37.5,
        'Vehicle.CurrentLocation.Longitude': 127.0,
      });

      await tester.pumpAndSettle();

      expect(find.textContaining('VEHICLE ID: KONA'), findsOneWidget);
      expect(find.text('동력 및 제어'), findsOneWidget);
      expect(find.text('위치 및 자세'), findsOneWidget);
      expect(find.text('동적 거동'), findsOneWidget);
      expect(find.text('조명 및 신호'), findsOneWidget);
      expect(find.text('환경 및 연료'), findsOneWidget);
      expect(find.text('주행 이력'), findsOneWidget);

      final checkbox = find.byType(Checkbox).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    });

    testWidgets('ObdDataPage renders all sections', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ObdDataPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('데이터 파일'), findsOneWidget);
      expect(find.text('파워트레인'), findsOneWidget);
      expect(find.text('주행 상태'), findsOneWidget);
      expect(find.text('위치 정보'), findsOneWidget);
    });

    testWidgets('ReceiverPage validates port number', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = GrpcClient(host: '127.0.0.1', port: 50052);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReceiverPage(cloud: client))));
      await tester.pumpAndSettle();

      final portField = find.widgetWithText(TextField, '포트');
      await tester.enterText(portField, '999999');
      await tester.tap(find.text('GET'));
      await tester.pump();
      expect(find.text('유효한 포트 번호를 입력해 주세요.'), findsOneWidget);
    });

    testWidgets('ReceiverPage renders stream data and errors correctly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = GrpcClient(host: '127.0.0.1', port: 50052);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReceiverPage(cloud: client))));
      await tester.pumpAndSettle();

      // 1) Emit DataPackages with JSON & standard values
      final testPack = DataPackages();
      final pkg1 = DataPackages_DataPackage()..path = 'Vehicle.Speed';
      pkg1.dp.add(DataPackages_DataPackage_DataPoint()
        ..value = '{"speed": 85.5, "unit": "km/h"}'
        ..ts = '2026-08-25T12:00:00Z');
      final pkg2 = DataPackages_DataPackage()..path = 'Vehicle.Gear';
      pkg2.dp.add(DataPackages_DataPackage_DataPoint()
        ..value = '[1, 2, 3]'
        ..ts = '2026-08-25T12:00:01Z');
      final pkg3 = DataPackages_DataPackage()..path = 'Vehicle.Raw';
      pkg3.dp.add(DataPackages_DataPackage_DataPoint()
        ..value = 'RAW_VALUE'
        ..ts = '2026-08-25T12:00:02Z');
      testPack.data.addAll([pkg1, pkg2, pkg3]);

      client.emitEvent(testPack);
      await tester.pumpAndSettle();

      expect(find.text('Vehicle.Speed'), findsOneWidget);
      expect(find.text('Vehicle.Gear'), findsOneWidget);
      expect(find.text('Vehicle.Raw'), findsOneWidget);

      // 2) Emit empty data package
      client.emitEvent(DataPackages());
      await tester.pumpAndSettle();
      expect(find.text('데이터 없음'), findsOneWidget);

      // 3) Emit ErrorResponseMessage
      final errMsg = ErrorResponseMessage()
        ..number = '404'
        ..reason = 'NotFound'
        ..description = 'Path does not exist';
      client.emitError(errMsg);
      await tester.pumpAndSettle();
      expect(find.textContaining('코드: 404'), findsOneWidget);
      expect(find.textContaining('Path does not exist'), findsOneWidget);
    });
  });
}
