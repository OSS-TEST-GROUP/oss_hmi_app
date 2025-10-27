import 'package:flutter/material.dart';

class DataCard extends StatelessWidget {
  final String label;
  final String value;
  const DataCard({super.key, required this.label, required this.value,});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        Card.outlined(
          color: const Color.fromARGB(255, 235, 235, 235),
          child:Padding(
            padding: const EdgeInsets.all(10),
            child: Text(value),
          ),
        ),
      ],
    );
  }

}