import 'package:flutter/material.dart';
// import 'package:get/get.dart';
import 'package:adsw_monitor/model/key_value_item.dart';

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
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(left: 50, top: 20, right: 50),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: const Color.fromARGB(255, 218, 218, 218), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 30, top: 10, right: 20, bottom: 10),
        title: Text(title),
        children: items.map((item) {
          return ListTile(
            title: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.keyLabel),
                  Text(item.value),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}