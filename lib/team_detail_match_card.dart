import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VTeamDetailMatchCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final String? result;
  final String venue;
  final String dateDay;
  final int dateNum;
  final String dateMonth;
  final String timeString;
  final bool isHomeTeam;

  const VTeamDetailMatchCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.result,
    required this.venue,
    required this.dateDay,
    required this.dateNum,
    required this.dateMonth,
    required this.timeString,
    this.isHomeTeam = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = result != null && result!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cardBgAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: Text(dateDay, style: VTextStyles.caption)),
                    Expanded(
                      child: Text(
                        dateNum.toString(),
                        style: VTextStyles.dateBig,
                      ),
                    ),
                    Expanded(
                      child: Text(dateMonth, style: VTextStyles.dateSmall),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Text('$dateDay $timeString', style: VTextStyles.caption),
              ),

              // Status
              if (hasResult)
                Text(result!, style: VTextStyles.scoreText)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cardBgAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TEKOMST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  homeTeam,
                  style: VTextStyles.bodyBold.copyWith(
                    color: isHomeTeam ? accentYellow : light,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Text(
                  '-',
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
              ),
              Expanded(
                child: Text(
                  awayTeam,
                  style: VTextStyles.bodyBold.copyWith(
                    color: !isHomeTeam ? accentYellow : light,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}
