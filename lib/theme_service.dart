import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _keyDarkMode = 'is_dark_mode';
  static final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    darkModeNotifier.value = prefs.getBool(_keyDarkMode) ?? true;
  }

  static bool get isDarkMode => darkModeNotifier.value;

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
    darkModeNotifier.value = value;
  }

  static Future<void> toggleDarkMode() async {
    await setDarkMode(!darkModeNotifier.value);
  }
}
