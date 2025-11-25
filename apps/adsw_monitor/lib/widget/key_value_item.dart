import 'package:flutter/material.dart';

class KeyValueItem extends StatelessWidget{
  final String label;
  final String value;
  final String? subtitle;
  final StatusType status;// = StatusType.good;

  const KeyValueItem({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.status = StatusType.good,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 19,
                color: Color(0xFF9CA3AF),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // 오른쪽 값 + (옵션) 서브타이틀
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1) 메인 값 (한 줄)
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // 2) (옵션) 서브타이틀: 작은 글씨, 여러 줄 허용
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF9CA3AF),
                        height: 1.25,
                      ),
                      softWrap: true,
                    ),
                  ),
              ],
            ),
          ),
          // Row(
          //   children: [
          //     _buildStatusIndicator(status),
          //     const SizedBox(width: 4),
          //     Text(
          //       value,
          //       style: const TextStyle(
          //         fontSize: 17,
          //         color: Colors.white,
          //         fontFamily: 'monospace',
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  // Widget _buildStatusIndicator(StatusType status) {
  //   Color color;
  //   IconData icon;

  //   switch (status) {
  //     case StatusType.good:
  //       color = const Color(0xFF10B981);
  //       icon = Icons.check_circle;
  //       break;
  //     case StatusType.warning:
  //       color = const Color(0xFFF59E0B);
  //       icon = Icons.warning;
  //       break;
  //     case StatusType.error:
  //       color = const Color(0xFFEF4444);
  //       icon = Icons.error;
  //       break;
  //   }

  //   return Icon(icon, color: color, size: 12);
  // }

}

enum StatusType {
  good,
  warning,
  error,
}