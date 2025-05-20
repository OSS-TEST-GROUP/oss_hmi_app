import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oss_hmi_app/controllers/adsw_collector.dart';

class AdswViewPage extends StatefulWidget {
  const AdswViewPage({super.key});
  
  @override
  State<AdswViewPage> createState() => _AdswViewPageState();
}

class _AdswViewPageState extends State<AdswViewPage> {

  late final AdswCollector _adswCollector;

  @override
  Widget build(BuildContext context) {

    return const Column(
      children: <Widget>[
        // Date Widget Views
      ]
    );
  }
}