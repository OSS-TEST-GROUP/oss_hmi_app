import 'package:flutter/material.dart';
// import 'package:get/get.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';

class DataViewWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final StatusType status;
  final List<Widget> children;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? button;

  const DataViewWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.status,
    required this.isExpanded,
    required this.onTap,
    required this.children,
    this.button,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF374151), width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: iconColor, size: 23),
                        ),
                        const SizedBox(width: 15),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (button != null) button!,
                        //_buildStatusIndicator(status),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    color: const Color(0xFF9CA3AF),
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF374151), width: 0.3)),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
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