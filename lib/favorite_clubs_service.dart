import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './main.dart';

/// Club-level favoriting, separate from team favorites in [FavoritesService].
/// Deliberately does NOT fold a favorited club's teams into the home match
/// feed - some clubs (e.g. Mendo Booischot) field ~50 teams, and eagerly
/// loading all of them on every refresh would mean dozens of API calls. A
/// favorited club just gets a shortcut into its existing ClubDetailPage,
/// which already lazy-loads each team row on demand.
class FavoriteClubsService {
  static const String _keyFavoriteClubs = 'favorite_clubs_v1';

  static final ValueNotifier<int> favoriteClubsNotifier = ValueNotifier<int>(
    0,
  );

  static void _notify() {
    favoriteClubsNotifier.value++;
  }

  /// Save a ClubModel (only clubId and label are persisted - enough to
  /// re-fetch the full club via ClubModel.load()).
  static Future<void> addFavorite(ClubModel club) async {
    final prefs = await SharedPreferences.getInstance();
    final List<ClubModel> favorites = await loadFavorites();

    if (!favorites.any((c) => c.clubId == club.clubId)) {
      favorites.add(ClubModel(clubId: club.clubId, label: club.label));
      await _saveList(prefs, favorites);
      _notify();
    }
  }

  static Future<void> removeFavorite(String clubId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<ClubModel> favorites = await loadFavorites();

    favorites.removeWhere((c) => c.clubId == clubId);
    await _saveList(prefs, favorites);
    _notify();
  }

  static Future<bool> toggleFavorite(ClubModel club) async {
    final isFav = await isFavorite(club.clubId);
    if (isFav) {
      await removeFavorite(club.clubId);
      return false;
    } else {
      await addFavorite(club);
      return true;
    }
  }

  static Future<List<ClubModel>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_keyFavoriteClubs);

    if (jsonList == null || jsonList.isEmpty) {
      return [];
    }

    return jsonList.map((item) {
      final Map<String, dynamic> jsonMap = jsonDecode(item);
      return ClubModel(
        clubId: jsonMap['club_id'] ?? '',
        label: jsonMap['label'] ?? '',
      );
    }).toList();
  }

  static Future<bool> isFavorite(String clubId) async {
    final favorites = await loadFavorites();
    return favorites.any((c) => c.clubId == clubId);
  }

  static Future<void> _saveList(
    SharedPreferences prefs,
    List<ClubModel> favorites,
  ) async {
    final List<String> jsonList = favorites.map((c) {
      return jsonEncode({'club_id': c.clubId, 'label': c.label});
    }).toList();

    await prefs.setStringList(_keyFavoriteClubs, jsonList);
  }
}
