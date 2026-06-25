import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'league_badge.dart';

class VClubTeamRow extends StatelessWidget {
  final String teamName;
  final String seriesLabel;
  final String? ranking;
  final String? nextMatch;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const VClubTeamRow({
    super.key,
    required this.teamName,
    required this.seriesLabel,
    this.ranking,
    this.nextMatch,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: VTextStyles.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      VLeagueBadge(label: seriesLabel),
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

            if (ranking != null && ranking!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 11,
                    color: accentYellow,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Huidige stand: $ranking',
                    style: VTextStyles.bodySecondary,
                  ),
                ],
              ),
            ],

            if (nextMatch != null && nextMatch!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(color: cardBorder, height: 1),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_forward,
                    size: 10,
                    color: accentYellow,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(nextMatch!, style: VTextStyles.bodySecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
