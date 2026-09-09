import 'package:flutter/material.dart';
import 'package:diag_monitor/theme/diag_palette.dart';

class KeyValueItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final StatusType status; // = StatusType.good;

  const KeyValueItem({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.status = StatusType.good,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DiagPaletteScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flexible(
          //   child: Text(
          //     label,
          //     style: const TextStyle(
          //       fontSize: 19,
          //       color: Color(0xFF9CA3AF),
          //     ),
          //     overflow: TextOverflow.ellipsis,
          //   ),
          // ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: palette.muted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // 오른쪽 값 + (옵션) 서브타이틀
          // Flexible(
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.end,
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       // 1) 메인 값 (한 줄)
          //       Text(
          //         value,
          //         textAlign: TextAlign.right,
          //         style: const TextStyle(
          //           fontSize: 17,
          //           color: Colors.white,
          //           fontFamily: 'monospace',
          //         ),
          //         overflow: TextOverflow.ellipsis,
          //       ),
          //       // 2) (옵션) 서브타이틀: 작은 글씨, 여러 줄 허용
          //       if (subtitle != null && subtitle!.isNotEmpty)
          //         Padding(
          //           padding: const EdgeInsets.only(top: 4),
          //           child: Text(
          //             subtitle!,
          //             textAlign: TextAlign.right,
          //             style: const TextStyle(
          //               fontSize: 15,
          //               color: Color(0xFF9CA3AF),
          //               height: 1.25,
          //             ),
          //             softWrap: true,
          //           ),
          //         ),
          //     ],
          //   ),
          // ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ✅ 스크롤 가능한 값 영역 (JSON 전체 표시)
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 180, // 필요하면 조절
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    //color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.text,
                        fontFamily: 'monospace',
                        height: 1.3,
                      ),
                    ),
                  ),
                ),

                /// 🔹 subtitle (옵션)
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.muted,
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

enum StatusType { good, warning, error }
