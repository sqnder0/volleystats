import './main.dart';
import './favorite_service.dart';
import './notification_service.dart';
import './persistence_service.dart';
import './logger.dart';

/// Periodically (and on app resume) re-fetches favorite teams and compares
/// each game's result against the last-seen value, firing a local
/// notification the first time a result appears or changes. This is a
/// client-side polling approach: reliable on Android via a WorkManager
/// background task, best-effort on iOS since it otherwise only runs when
/// the app is actually opened/resumed.
class ResultsWatcherService {
  static bool _isChecking = false;

  static Future<void> checkForNewResults() async {
    // Avoid overlapping runs (e.g. a WorkManager tick firing while the
    // app-resume check from the same session is still in flight).
    if (_isChecking) return;
    _isChecking = true;

    try {
      final enabled = await FavoritesService.areResultNotificationsEnabled();
      if (!enabled) return;

      final favorites = await FavoritesService.loadFavorites();
      if (favorites.isEmpty) return;

      final lastResults = await PersistenceService.loadLastResults();
      final Map<String, dynamic> updated = Map<String, dynamic>.from(
        lastResults,
      );
      bool changed = false;

      for (final favTeam in favorites) {
        try {
          final fullTeam = await favTeam.load(forceReload: true);

          for (final game in fullTeam.games) {
            // Every match we've ever looked at is tracked here, played or
            // not (unplayed matches are stored as ''), so a match that
            // already existed as "seen but unplayed" can be told apart from
            // one this app has genuinely never encountered before. Without
            // that, a first-time result and a first-ever run look identical
            // (the matchCode is simply absent from lastResults either way)
            // and legitimately new results would never notify.
            final previous = lastResults[game.matchCode] as String?;
            if (previous == game.result) continue;

            updated[game.matchCode] = game.result;
            changed = true;

            // Only notify when a match we'd already been tracking (as
            // unplayed) just got its result - not when the matchCode is
            // brand new to us, which covers first install (every
            // already-played match would otherwise fire at once) and newly
            // scheduled matches appearing with a result already attached.
            if (previous == '' && game.result.isNotEmpty) {
              await _notifyResult(fullTeam.name, favTeam.teamId, game);
            }
          }
        } catch (e) {
          log('ResultsWatcherService', 'failed for ${favTeam.label}', error: e);
        }
      }

      if (changed) {
        await PersistenceService.saveLastResults(updated);
      }
    } finally {
      _isChecking = false;
    }
  }

  static Future<void> _notifyResult(
    String teamName,
    String teamId,
    GameModel game,
  ) async {
    final bool? won = game.didTeamWin(teamId);
    final opponent = game.homeTeam.teamId == teamId
        ? game.awayTeam.name
        : game.homeTeam.name;
    final outcome = won == true
        ? 'gewonnen'
        : won == false
        ? 'verloren'
        : 'gespeeld';

    await NotificationService.showResultNotification(
      id: game.matchCode.hashCode & 0x7FFFFFFF,
      title: '$teamName heeft $outcome',
      body: '${game.result} tegen $opponent',
    );
  }
}
