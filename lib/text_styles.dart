import 'package:flutter/material.dart';
import './colors.dart';

class VTextStyles {
  static const String _fontHeading = 'SpaceGrotesk';
  static const String _fontBody = 'DM Sans';

  static TextStyle get h1 => TextStyle(
    fontFamily: _fontHeading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: light,
    height: 1.1,
  );

  static TextStyle get h2 => TextStyle(
    fontFamily: _fontHeading,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: light,
  );

  static TextStyle get h3 => TextStyle(
    fontFamily: _fontHeading,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: light,
  );

  static TextStyle get bodyBold => TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: light,
  );

  static TextStyle get body => TextStyle(
    fontFamily: _fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: light,
  );

  static TextStyle get bodySecondary => TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondary,
  );

  static TextStyle get bodySecondaryBright => TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondaryBright,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: _fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: secondary,
  );

  static TextStyle get captionBold => TextStyle(
    fontFamily: _fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: secondary,
  );

  static TextStyle get smallLabel => TextStyle(
    fontFamily: _fontBody,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: secondary,
    letterSpacing: 0.3,
  );

  static TextStyle get statNumber => TextStyle(
    fontFamily: _fontHeading,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: accentYellow,
  );

  static TextStyle get scoreText => TextStyle(
    fontFamily: _fontHeading,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: light,
  );

  static TextStyle get vsText => TextStyle(
    fontFamily: _fontBody,
    fontSize: 18,
    fontWeight: FontWeight.w300,
    color: secondary,
  );

  static TextStyle get dateBig => TextStyle(
    fontFamily: _fontHeading,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: light,
    height: 1,
  );

  static TextStyle get dateSmall => TextStyle(
    fontFamily: _fontBody,
    fontSize: 8,
    fontWeight: FontWeight.w600,
    color: secondary,
    textBaseline: TextBaseline.alphabetic,
  );

  static TextStyle get rankPts => TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: accentYellow,
  );

  static TextStyle get badgeText => TextStyle(
    fontFamily: _fontBody,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );
}
