// import 'package:get/get.dart';

// class KeyValueItem {
//   final String keyLabel;
//   final String value;

//   KeyValueItem({required this.keyLabel, required this.value});

// }

import 'package:flutter/material.dart';

class KeyValueItem extends StatelessWidget{
  final String label;
  final String value;
  final StatusType status;// = StatusType.good;

  const KeyValueItem({
    super.key,
    required this.label,
    required this.value,
    this.status = StatusType.good,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            )
          ),
          Row(
            children: [
              _buildStatusIndicator(status),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(StatusType status) {
    Color color;
    IconData icon;

    switch (status) {
      case StatusType.good:
        color = const Color(0xFF10B981);
        icon = Icons.check_circle;
        break;
      case StatusType.warning:
        color = const Color(0xFFF59E0B);
        icon = Icons.warning;
        break;
      case StatusType.error:
        color = const Color(0xFFEF4444);
        icon = Icons.error;
        break;
    }

    return Icon(icon, color: color, size: 12);
  }

}

enum StatusType {
  good,
  warning,
  error,
}