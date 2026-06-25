import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const VInfoCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: VTextStyles.smallLabel),
          const SizedBox(height: 4),
          Text(
            value,
            style: VTextStyles.bodyBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
