import 'package:flutter/material.dart';
// import 'package:get/get.dart';
import 'package:adsw_monitor/theme/adsw_palette.dart';
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
    final palette = AdswPaletteScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(icon, color: palette.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: palette.text,
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
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: palette.muted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.line, width: 1)),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.valueSurface,
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
