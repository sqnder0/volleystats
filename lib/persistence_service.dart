import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

class PersistenceService {
  static const String _keyClubCache = 'cache_clubs_v1';
  static const String _keyTeamCache = 'cache_teams_v1';
  static const String _keyLastResults = 'last_results_v1';
  static const String _keyMatchReminderIds = 'match_reminder_ids_v1';

  static Future<Map<String, dynamic>> loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      log('PersistenceService', 'Error decoding cache $key', error: e);
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

  /// Last-seen result string per matchCode, used by [ResultsWatcherService]
  /// to detect when a favorite team's match result changes.
  static Future<Map<String, dynamic>> loadLastResults() =>
      loadCache(_keyLastResults);
  static Future<void> saveLastResults(Map<String, dynamic> data) =>
      saveCache(_keyLastResults, data);

  /// Ids of currently-scheduled match-start reminder notifications, so a
  /// reschedule can cancel exactly those (not a blanket cancelAll(), which
  /// would also wipe out the unrelated daily-summary/result notifications).
  static Future<List<int>> loadMatchReminderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyMatchReminderIds) ?? [];
    return list.map(int.parse).toList();
  }

  static Future<void> saveMatchReminderIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyMatchReminderIds,
      ids.map((i) => i.toString()).toList(),
    );
  }
}
