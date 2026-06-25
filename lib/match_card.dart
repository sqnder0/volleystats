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
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = result != null && result!.isNotEmpty;

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
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulsingDot(),
                              SizedBox(width: 4),
                              Text(
                                'AFGEWERKT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentRed,
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
                              ? Text(result!, style: VTextStyles.scoreText)
                              : const Text('vs', style: VTextStyles.vsText),
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
                        const Icon(
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
  const _PulsingDot();

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
        decoration: const BoxDecoration(
          color: accentRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
