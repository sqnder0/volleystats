import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VFavoriteClubCard extends StatelessWidget {
  final String clubName;
  final int? competitionTeamCount;
  final int? cupTeamCount;
  final VoidCallback? onTap;
  final VoidCallback? onRemoveTap;

  const VFavoriteClubCard({
    super.key,
    required this.clubName,
    this.competitionTeamCount,
    this.cupTeamCount,
    this.onTap,
    this.onRemoveTap,
  });

  const VFavoriteClubCard.loading({super.key, required this.clubName})
    : competitionTeamCount = null,
      cupTeamCount = null,
      onTap = null,
      onRemoveTap = null;

  @override
  Widget build(BuildContext context) {
    final totalTeams = (competitionTeamCount ?? 0) + (cupTeamCount ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 22,
                color: accentYellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clubName,
                    style: VTextStyles.bodyBold.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (totalTeams > 0)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _CountChip(
                          icon: Icons.groups_outlined,
                          label: totalTeams == 1
                              ? '1 team'
                              : '$totalTeams teams',
                        ),
                        if ((cupTeamCount ?? 0) > 0)
                          _CountChip(
                            icon: Icons.emoji_events_outlined,
                            label: '$cupTeamCount in beker',
                          ),
                      ],
                    )
                  else
                    Text('Club', style: VTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemoveTap,
              child: const Icon(Icons.star, size: 14, color: accentYellow),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CountChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: secondary),
          const SizedBox(width: 4),
          Text(label, style: VTextStyles.caption),
        ],
      ),
    );
  }
}
