import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VLeagueBadge extends StatelessWidget {
  final String label;

  const VLeagueBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accentYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: VTextStyles.badgeText.copyWith(color: accentYellow),
      ),
    );
  }
}
