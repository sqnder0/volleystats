import 'package:flutter/material.dart';
import 'theme_service.dart';
import 'theme_palette.dart';

// ============================================================
// THEME MAPPING
// Use this file to map VPalette colors to UI properties.
// ============================================================

Color get primary =>
    ThemeService.isDarkMode ? VPalette.navyDark : VPalette.whiteGhost;

Color get light =>
    ThemeService.isDarkMode ? VPalette.textWhite : VPalette.textBlack;

Color get secondary =>
    ThemeService.isDarkMode ? VPalette.textGrey : VPalette.textSlateLight;

Color get secondaryBright =>
    ThemeService.isDarkMode ? VPalette.textSlate : VPalette.textSlateDeep;

Color get cardBg =>
    ThemeService.isDarkMode ? VPalette.cardDark : VPalette.whitePure;

Color get cardBorder =>
    ThemeService.isDarkMode ? VPalette.borderDark : VPalette.borderLight;

Color get cardBgAlt =>
    ThemeService.isDarkMode ? VPalette.cardAltDark : VPalette.whiteAlt;

Color get skeletonColor => ThemeService.isDarkMode
    ? Colors.white.withValues(alpha: 0.06)
    : Colors.black.withValues(alpha: 0.04);

// Static Brand Colors
const Color accentYellow = VPalette.yellow;
const Color accentRed = VPalette.red;
const Color dark = VPalette.pureDark;

// Explicit Palette Access
const Color textSlateDeep = VPalette.textSlateDeep;

// Feature-specific dynamic colors
Color get blueInfo => VPalette.blueInfo;
Color get purpleLanguage => VPalette.purpleLanguage;
Color get alertGold =>
    ThemeService.isDarkMode ? VPalette.yellow : VPalette.alertDarkGold;
