import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'league_badge.dart';

class VClubTeamRow extends StatelessWidget {
  final String teamName;
  final String seriesLabel;
  final String? nextMatch;
  final String? venue;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const VClubTeamRow({
    super.key,
    required this.teamName,
    required this.seriesLabel,
    this.nextMatch,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
    this.venue,
  });

  const VClubTeamRow.loading({super.key})
    : teamName = '',
      seriesLabel = '',
      nextMatch = null,
      venue = null,
      isFavorite = false,
      onTap = null,
      onFavoriteTap = null;

  @override
  Widget build(BuildContext context) {
    final isLoading = teamName.isEmpty;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
                      isLoading
                          ? const _SkeletonBox(width: 140, height: 14)
                          : Text(
                              teamName,
                              style: VTextStyles.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      const SizedBox(height: 4),
                      isLoading
                          ? const _SkeletonBox(width: 90, height: 12)
                          : VLeagueBadge(label: seriesLabel),
                    ],
                  ),
                ),
                if (!isLoading)
                  GestureDetector(
                    onTap: onFavoriteTap,
                    child: Icon(
                      Icons.star,
                      size: 14,
                      color: isFavorite ? accentYellow : secondary,
                    ),
                  )
                else
                  const _SkeletonCircle(size: 14),
              ],
            ),
            if (!isLoading && nextMatch != null) ...[
              const SizedBox(height: 10),
              const Divider(color: cardBorder, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.navigate_next_rounded,
                    size: 16,
                    color: secondaryBright,
                  ),
                  Expanded(
                    child: Text(
                      nextMatch!,
                      style: VTextStyles.bodySecondaryBright,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: secondary,
                    size: 14,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 2),
                    child: Text(venue!, style: VTextStyles.caption),
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

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;
  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        shape: BoxShape.circle,
      ),
    );
  }
}
