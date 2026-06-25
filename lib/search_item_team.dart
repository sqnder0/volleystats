import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'league_badge.dart';

class VSearchItemTeam extends StatelessWidget {
  final String name;
  final String leagueName;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const VSearchItemTeam({
    super.key,
    required this.name,
    required this.leagueName,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
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
                color: accentYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_volleyball_outlined,
                size: 15,
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
                  const SizedBox(height: 3),
                  VLeagueBadge(label: leagueName),
                ],
              ),
            ),

            GestureDetector(
              onTap: onFavoriteTap,
              child: Icon(
                Icons.star,
                size: 14,
                color: isFavorite ? accentYellow : secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
