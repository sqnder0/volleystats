import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VRankingRow extends StatelessWidget {
  final int position;
  final String teamName;
  final int wins;
  final int losses;
  final int setsWon;
  final int setsLost;
  final int points;
  final bool isFavorite;
  final bool isHeader;

  const VRankingRow({
    super.key,
    required this.position,
    required this.teamName,
    required this.wins,
    required this.losses,
    required this.setsWon,
    required this.setsLost,
    required this.points,
    this.isFavorite = false,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      return _buildHeader();
    }

    return Container(
      height: 48,
      decoration: isFavorite
          ? BoxDecoration(
              color: accentYellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: isFavorite
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 10)
          : const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              position.toString(),
              style: VTextStyles.bodyBold,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              teamName,
              style: VTextStyles.bodyBold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildStatCell(wins.toString()),
          _buildStatCell(losses.toString()),
          _buildStatCell(setsWon.toString()),
          _buildStatCell(setsLost.toString()),
          SizedBox(
            width: 42,
            child: Text(
              points.toString(),
              style: VTextStyles.rankPts,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: VTextStyles.smallLabel,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: Text('TEAM', style: VTextStyles.smallLabel)),
          SizedBox(
            width: 36,
            child: Text(
              'W',
              style: VTextStyles.smallLabel,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              'V',
              style: VTextStyles.smallLabel,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              'S+',
              style: VTextStyles.smallLabel,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              'S-',
              style: VTextStyles.smallLabel,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              'PT',
              style: VTextStyles.smallLabel,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String value) {
    return SizedBox(
      width: 36,
      child: Text(
        value,
        style: VTextStyles.bodySecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}
