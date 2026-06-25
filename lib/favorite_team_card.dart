import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'league_badge.dart';

class VFavoriteTeamCard extends StatelessWidget {
  final String teamName;
  final String leagueName;
  final String? clubName;
  final String? nextHomeTeam;
  final String? nextAwayTeam;
  final String? nextDateDay;
  final int? nextDateDayNum;
  final String? nextDateMonth;
  final String? nextTime;
  final bool hasUpcomingMatch;
  final VoidCallback? onTap;
  final VoidCallback? onRemoveTap;

  const VFavoriteTeamCard({
    super.key,
    required this.teamName,
    required this.leagueName,
    this.clubName,
    this.nextHomeTeam,
    this.nextAwayTeam,
    this.nextDateDay,
    this.nextDateDayNum,
    this.nextDateMonth,
    this.nextTime,
    this.hasUpcomingMatch = false,
    this.onTap,
    this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
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
                        style: VTextStyles.bodyBold.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      VLeagueBadge(label: leagueName),
                      if (clubName != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 12,
                              color: secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(clubName!, style: VTextStyles.caption),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                GestureDetector(
                  onTap: onRemoveTap,
                  child: const Icon(Icons.star, size: 14, color: accentYellow),
                ),
              ],
            ),

            if (hasUpcomingMatch) ...[
              const SizedBox(height: 12),
              const Divider(color: cardBorder, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Column(
                      children: [
                        Text(nextDateDay ?? '', style: VTextStyles.caption),
                        Text(
                          nextDateDayNum.toString(),
                          style: VTextStyles.dateBig,
                        ),
                        Text(nextDateMonth ?? '', style: VTextStyles.dateSmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$nextHomeTeam vs $nextAwayTeam',
                          style: VTextStyles.bodySecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 11,
                              color: secondary,
                            ),
                            const SizedBox(width: 3),
                            Text(nextTime ?? '', style: VTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right, size: 11, color: secondary),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Divider(color: cardBorder, height: 1),
              const SizedBox(height: 12),
              const Text(
                'Geen geplande wedstrijden',
                style: VTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
