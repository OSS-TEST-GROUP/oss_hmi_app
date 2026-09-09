import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.items,
    this.leadingIcon = Icons.speed,        // 제목 왼쪽 아이콘
    this.gradient,
    this.borderColor = const Color.fromARGB(255, 238, 238, 238),
    this.titleColor = const Color.fromARGB(255, 68, 68, 68),
    this.valueTextStyle,
  });

  /// 카드 상단 제목
  final String title;

  /// 표시할 키-값 목록
  /// 예: [{'label': 'MODEL ID', 'value': 'KONA'}, ...]
  final List<Map<String, String>> items;

  /// 제목 옆 아이콘
  final IconData leadingIcon;

  /// 배경 그라데이션 (없으면 기본 연한 파랑)
  final Gradient? gradient;

  /// 테두리 색
  final Color borderColor;

  /// 제목 색
  final Color titleColor;

  /// 값 글자 스타일 (없으면 기본은 검정)
  final TextStyle? valueTextStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        // gradient: gradient ??
        //     const LinearGradient(
        //       colors: [
        //         Color.fromARGB(255, 255, 255, 255),
        //         Color.fromARGB(255, 255, 255, 255),
        //       ],
        //       begin: Alignment.topLeft,
        //       end: Alignment.bottomRight,
        //     ),
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 영역
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leadingIcon, color: titleColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 키-값 목록
          ...items.map((item) {
            final label = item['label'] ?? '';
            final value = item['value'] ?? '-';
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF526070),
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: valueTextStyle ??
                        const TextStyle(
                          color: Color(0xFF131722),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
