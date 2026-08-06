import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  static const String _keyClubCache = 'cache_clubs_v1';
  static const String _keyTeamCache = 'cache_teams_v1';
  static const String _keyLeagueCache = 'cache_leagues_v1';

  static Future<Map<String, dynamic>> loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      debugPrint('Error decoding cache $key: $e');
      return {};
    }
  }

  static Future<void> saveCache(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<Map<String, dynamic>> loadClubs() => loadCache(_keyClubCache);
  static Future<void> saveClubs(Map<String, dynamic> data) =>
      saveCache(_keyClubCache, data);

  static Future<Map<String, dynamic>> loadTeams() => loadCache(_keyTeamCache);
  static Future<void> saveTeams(Map<String, dynamic> data) =>
      saveCache(_keyTeamCache, data);

  static Future<Map<String, dynamic>> loadLeagues() =>
      loadCache(_keyLeagueCache);
  static Future<void> saveLeagues(Map<String, dynamic> data) =>
      saveCache(_keyLeagueCache, data);
}
