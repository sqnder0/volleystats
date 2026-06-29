import 'package:flutter/material.dart';
import './colors.dart';

class VTextStyles {
  static const String _fontHeading = 'SpaceGrotesk';
  static const String _fontBody = 'DM Sans';

  static const TextStyle h1 = TextStyle(
    fontFamily: _fontHeading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: light,
    height: 1.1,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontHeading,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: light,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontHeading,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: light,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: light,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: light,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondary,
  );

  static const TextStyle bodySecondaryBright = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondaryBright,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: secondary,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: _fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: secondary,
  );

  static const TextStyle smallLabel = TextStyle(
    fontFamily: _fontBody,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: secondary,
    letterSpacing: 0.3,
  );

  static const TextStyle statNumber = TextStyle(
    fontFamily: _fontHeading,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: accentYellow,
  );

  static const TextStyle scoreText = TextStyle(
    fontFamily: _fontHeading,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: light,
  );

  static const TextStyle vsText = TextStyle(
    fontFamily: _fontBody,
    fontSize: 18,
    fontWeight: FontWeight.w300,
    color: secondary,
  );

  static const TextStyle dateBig = TextStyle(
    fontFamily: _fontHeading,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: light,
    height: 1,
  );

  static const TextStyle dateSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: 8,
    fontWeight: FontWeight.w600,
    color: secondary,
    textBaseline: TextBaseline.alphabetic,
  );

  static const TextStyle rankPts = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: accentYellow,
  );

  static const TextStyle badgeText = TextStyle(
    fontFamily: _fontBody,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );
}
