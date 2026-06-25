import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VDateDivider extends StatelessWidget {
  final String label;
  final String? countLabel;

  const VDateDivider({super.key, required this.label, this.countLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: VTextStyles.bodyBold.copyWith(
              fontSize: 12,
              color: accentYellow,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: cardBorder, height: 1)),
          if (countLabel != null) ...[
            const SizedBox(width: 10),
            Text(countLabel!, style: VTextStyles.caption),
          ],
        ],
      ),
    );
  }
}
