import 'package:flutter/material.dart';

import 'package:ota_monitor/theme/app_palette.dart';

class KeyValueItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final StatusType status;
  final VoidCallback? onSubtitleTap;

  const KeyValueItem({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.status = StatusType.good,
    this.onSubtitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 19,
                color: p.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 17,
                    color: p.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: onSubtitleTap != null
                        ? GestureDetector(
                            onTap: onSubtitleTap,
                            child: Text(
                              subtitle!,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 15,
                                color: p.accentBlue,
                                height: 1.25,
                                decoration: TextDecoration.underline,
                              ),
                              softWrap: true,
                            ),
                          )
                        : Text(
                            subtitle!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              color: p.textTertiary,
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