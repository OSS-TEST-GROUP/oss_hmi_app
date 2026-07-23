// Basic smoke test — verifies the app widget tree builds without errors.
// Full integration tests require a live rosbridge; this only exercises
// the standalone MaterialApp scaffold.

import 'package:flutter_test/flutter_test.dart';
import 'package:rviz2_monitor/main.dart';
import 'package:rviz2_monitor/ros_keeper.dart';

void main() {
  testWidgets('Rviz2MonitorApp renders status card', (tester) async {
    final cfg = AppConfig.defaults();
    final keeper = RosKeeper(cfg);
    final holder = RosKeeperHolder(keeper);

    await tester.pumpWidget(Rviz2MonitorApp(cfg: cfg, keeperHolder: holder));

    // Status card heading should be present.
    expect(find.text('rviz2 Container'), findsOneWidget);
    // Start button should be present.
    expect(find.text('Start'), findsOneWidget);
    // Stop button should be present.
    expect(find.text('Stop'), findsOneWidget);
  });
}
