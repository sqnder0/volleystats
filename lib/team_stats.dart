import './main.dart';

/// The team's current win/loss streak, walking played matches backwards from
/// the most recent, skipping unplayed ones. Null if the team hasn't played
/// yet.
({int count, bool isWin})? currentStreak(TeamModel team) {
  int count = 0;
  bool? isWin;
  for (final g in team.games.reversed) {
    final won = g.didTeamWin(team.teamId);
    if (won == null) continue;
    if (isWin == null) {
      isWin = won;
      count = 1;
    } else if (won == isWin) {
      count++;
    } else {
      break;
    }
  }
  if (isWin == null) return null;
  return (count: count, isWin: isWin);
}
