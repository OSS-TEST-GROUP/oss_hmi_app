import 'package:flutter/material.dart';

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onFieldTap,
    required this.onSend,
    required this.onVoiceTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFieldTap;
  final VoidCallback onSend;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD0D1D2)),
      ),
      child: compact
          ? Column(
              children: [
                _ComposerField(
                  controller: controller,
                  focusNode: focusNode,
                  onTap: onFieldTap,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ComposerIconButton(
                      icon: Icons.mic_none_rounded,
                      onPressed: onVoiceTap,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '샘플 음성 또는 키보드로 바로 명령',
                        style: TextStyle(color: Color(0xFF5C5E62)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SendButton(onPressed: onSend),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _ComposerIconButton(
                  icon: Icons.mic_none_rounded,
                  onPressed: onVoiceTap,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ComposerField(
                    controller: controller,
                    focusNode: focusNode,
                    onTap: onFieldTap,
                  ),
                ),
                const SizedBox(width: 12),
                _SendButton(onPressed: onSend),
              ],
            ),
    );
  }
}

class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
        showCursor: true,
        maxLines: 1,
        onTap: onTap,
        style: const TextStyle(
          color: Color(0xFF171A20),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '예: 내비게이션 앱 실행해줘',
          hintStyle: TextStyle(color: Color(0xFF8E8E8E)),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton(
        onPressed: onPressed,
        tooltip: '샘플 음성 이해',
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF4F4F4),
          foregroundColor: const Color(0xFF393C41),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3E6AE1),
        foregroundColor: Colors.white,
        minimumSize: const Size(120, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      icon: const Icon(Icons.arrow_upward_rounded),
      label: const Text('전송', style: TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}
