import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VStatCard extends StatelessWidget {
  final int value;
  final String label;
  final Color valueColor;
  final Color gradientStart;
  final Color gradientEnd;
  final Color borderColor;

  const VStatCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = accentYellow,
    this.gradientStart = const Color(0x1EFFC902),
    this.gradientEnd = const Color(0x0AFFC902),
    this.borderColor = const Color(0x26FFC902),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: VTextStyles.statNumber.copyWith(color: valueColor),
          ),
          const SizedBox(height: 2),
          Text(label, style: VTextStyles.bodySecondary),
        ],
      ),
    );
  }
}
