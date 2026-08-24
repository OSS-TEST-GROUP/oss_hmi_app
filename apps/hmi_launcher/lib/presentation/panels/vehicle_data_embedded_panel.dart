import 'package:flutter/material.dart';
import 'package:vehicle_data_app/main.dart' show VehicleDataViewPage;

/// Embeds Vehicle Data App's Receiver Page (수신 데이터 화면) in the launcher.
class VehicleDataEmbeddedPanel extends StatelessWidget {
  const VehicleDataEmbeddedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const VehicleDataViewPage();
  }
}
