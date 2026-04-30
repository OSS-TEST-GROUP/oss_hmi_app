import 'package:flutter/material.dart';

import 'package:ota_monitor/theme/app_palette.dart';
import 'package:ota_monitor/widget/key_value_item.dart';

class DataViewWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final StatusType status;
  final List<Widget> children;
  final bool isExpanded;
  final VoidCallback onTap;

  const DataViewWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.status = StatusType.good,
    required this.isExpanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(icon, color: iconColor, size: 23),
                        ),
                        const SizedBox(width: 15),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w500,
                              color: p.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: p.textTertiary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: p.divider, width: 1)),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
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