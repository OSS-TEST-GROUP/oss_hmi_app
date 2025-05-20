import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oss_hmi_app/controllers/mw_collector.dart';

class MwViewPage extends StatefulWidget {
  const MwViewPage({super.key});
  
  @override
  MwViewPageState createState() => MwViewPageState();
}

class MwViewPageState extends State<MwViewPage> {

  late final MwCollector _mwCollector;

  @override
  Widget build(BuildContext context) {

    return const Column(
      children: <Widget>[
        // Data View Widgets
      ],
    );
  }
}