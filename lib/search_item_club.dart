import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VSearchItemClub extends StatelessWidget {
  final String name;
  final String clubCode;
  final VoidCallback? onTap;

  const VSearchItemClub({
    super.key,
    required this.name,
    required this.clubCode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 16,
                color: accentYellow,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: VTextStyles.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(clubCode, style: VTextStyles.caption),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, size: 12, color: secondary),
          ],
        ),
      ),
    );
  }
}
