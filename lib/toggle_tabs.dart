import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VToggleTabs extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final int leftCount;
  final int rightCount;
  final bool isLeftActive;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;

  const VToggleTabs({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftCount,
    required this.rightCount,
    this.isLeftActive = true,
    this.onLeftTap,
    this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          _buildTab(
            label: '$leftLabel ($leftCount)',
            isActive: isLeftActive,
            onTap: onLeftTap,
          ),
          _buildTab(
            label: '$rightLabel ($rightCount)',
            isActive: !isLeftActive,
            onTap: onRightTap,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? cardBgAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: VTextStyles.bodyBold.copyWith(
              fontSize: 13,
              color: isActive ? light : secondary,
            ),
          ),
        ),
      ),
    );
  }
}
