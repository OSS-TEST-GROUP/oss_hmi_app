import 'package:flutter/material.dart';
// import 'package:get/get.dart';
import 'package:oss_hmi_app/models/key_value_item.dart';

class DataViewWidget extends StatelessWidget {
  final String title;
  final List<KeyValueItem> items;

  const DataViewWidget({
    super.key, 
    required this.title, 
    required this.items
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title),
      children: items.map((item) {
        return ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.keyLabel),
              Text(item.value),
            ],
          ),
        );
      }).toList(),
    );
  }
}