import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './main.dart';
import './notification_service.dart';

class FavoritesService {
  static const String _keyFavorites = 'favorite_teams_v1';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyNotificationHour = 'notification_hour';
  static const String _keyNotificationMinute = 'notification_minute';

  static final ValueNotifier<int> favoritesNotifier = ValueNotifier<int>(0);

  static void _notify() {
    favoritesNotifier.value++;
  }

  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? false;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  static Future<TimeOfDay> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyNotificationHour) ?? 8;
    final minute = prefs.getInt(_keyNotificationMinute) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<void> setNotificationTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotificationHour, time.hour);
    await prefs.setInt(_keyNotificationMinute, time.minute);
  }

  /// Preload all favorite teams into the global cache
  static Future<void> preloadFavorites() async {
    final favorites = await loadFavorites();
    final List<Map<String, dynamic>> allMatches = [];
    final Set<String> matchCodes = {};

    for (var favTeam in favorites) {
      try {
        final fullTeam = await favTeam.load();
        for (var game in fullTeam.games) {
          if (!matchCodes.contains(game.matchCode)) {
            matchCodes.add(game.matchCode);
            allMatches.add({
              'time': game.date, // DD/MM/YYYY
              'fav_name': fullTeam.name,
            });
          }
        }
      } catch (e) {
        // Silent error
      }
    }

    // Schedule notifications if enabled
    final enabled = await areNotificationsEnabled();
    if (enabled) {
      final time = await getNotificationTime();
      await NotificationService.scheduleDailySummaries(allMatches, time);
    }
  }

  /// Save a TeamModel (only teamId and label are persisted)
  static Future<void> addFavorite(TeamModel team) async {
    final prefs = await SharedPreferences.getInstance();
    final List<TeamModel> favorites = await loadFavorites();

    // Avoid duplicates
    if (!favorites.any((t) => t.teamId == team.teamId)) {
      favorites.add(TeamModel(teamId: team.teamId, label: team.label));
      await _saveList(prefs, favorites);
      // Start loading the full team data into cache
      team
          .load()
          .then((_) {
            // Update notifications if enabled
            preloadFavorites();
          })
          .catchError((e) {
            // Silent error
          });
      _notify();
    }
  }

  /// Remove a TeamModel by teamId
  static Future<void> removeFavorite(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<TeamModel> favorites = await loadFavorites();

    favorites.removeWhere((t) => t.teamId == teamId);
    await _saveList(prefs, favorites);
    // Update notifications if enabled
    preloadFavorites();
    _notify();
  }

  /// Toggle favorite status for a TeamModel
  static Future<bool> toggleFavorite(TeamModel team) async {
    final isFav = await isFavorite(team.teamId);
    if (isFav) {
      await removeFavorite(team.teamId);
      return false;
    } else {
      await addFavorite(team);
      return true;
    }
  }

  /// Load all saved TeamModels (contains teamId and label required for API calls)
  static Future<List<TeamModel>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_keyFavorites);

    if (jsonList == null || jsonList.isEmpty) {
      return [];
    }

    return jsonList.map((item) {
      final Map<String, dynamic> jsonMap = jsonDecode(item);
      return TeamModel(
        teamId: jsonMap['team_id'] ?? '',
        label: jsonMap['label'] ?? '',
      );
    }).toList();
  }

  /// Check if a team is favorited
  static Future<bool> isFavorite(String teamId) async {
    final favorites = await loadFavorites();
    return favorites.any((t) => t.teamId == teamId);
  }

  /// Helper to store serialized JSON string list
  static Future<void> _saveList(
    SharedPreferences prefs,
    List<TeamModel> favorites,
  ) async {
    final List<String> jsonList = favorites.map((t) {
      return jsonEncode({'team_id': t.teamId, 'label': t.label});
    }).toList();

    await prefs.setStringList(_keyFavorites, jsonList);
  }
}
