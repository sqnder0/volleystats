import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'league_badge.dart';

class VMatchCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final String? result;
  final String venue;
  final String leagueName;
  final String? time;
  final bool isFavTeamHome;
  final bool showFavBorder;

  /// Whether the favorite team in this match won (true), lost (false), or
  /// unknown/not applicable (null) - drives the badge/score coloring.
  final bool? favoriteWon;
  final VoidCallback? onTap;

  const VMatchCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.result,
    required this.venue,
    required this.leagueName,
    this.time,
    this.isFavTeamHome = false,
    this.showFavBorder = false,
    this.favoriteWon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = result != null && result!.isNotEmpty;
    final Color resultColor = favoriteWon == true
        ? accentGreen
        : favoriteWon == false
        ? accentRed
        : secondary;
    final String resultLabel = favoriteWon == true
        ? 'GEWONNEN'
        : favoriteWon == false
        ? 'VERLOREN'
        : 'AFGEWERKT';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            if (showFavBorder)
              Container(
                width: 3,
                decoration: const BoxDecoration(
                  color: accentYellow,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        VLeagueBadge(label: leagueName),
                        if (hasResult)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulsingDot(color: resultColor),
                              const SizedBox(width: 4),
                              Text(
                                resultLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: resultColor,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(time ?? '', style: VTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                homeTeam,
                                style: VTextStyles.bodyBold.copyWith(
                                  color: isFavTeamHome ? accentYellow : light,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isFavTeamHome ? 'Thuis' : 'Uit',
                                style: VTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: hasResult
                              ? Text(
                                  result!,
                                  style: VTextStyles.scoreText.copyWith(
                                    color: favoriteWon != null
                                        ? resultColor
                                        : null,
                                  ),
                                )
                              : Text('vs', style: VTextStyles.vsText),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                awayTeam,
                                style: VTextStyles.bodyBold.copyWith(
                                  color: !isFavTeamHome ? accentYellow : light,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                !isFavTeamHome ? 'Thuis' : 'Uit',
                                style: VTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: secondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            venue,
                            style: VTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({this.color = accentRed});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.4).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Opacity(
            opacity: 1.0 - (_animation.value - 1.0) * 2.5,
            child: child,
          ),
        );
      },
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
