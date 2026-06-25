import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VFilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const VFilterTab({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? accentYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? accentYellow : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: VTextStyles.bodyBold.copyWith(
            fontSize: 12,
            color: isActive ? primary : secondary,
          ),
        ),
      ),
    );
  }
}
