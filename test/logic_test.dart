import 'package:flutter_test/flutter_test.dart';
import 'package:volleystats/main.dart';
import 'package:volleystats/date_utils.dart' as date_utils;
import 'package:volleystats/team_stats.dart' as team_stats;

TeamModel _team(String id) => TeamModel(label: id, teamId: id);

GameModel _game({
  required TeamModel home,
  required TeamModel away,
  String result = '',
  String date = '01/01/2026',
  String matchCode = 'X-0001',
}) {
  return GameModel(
    matchCode: matchCode,
    day: 'Za',
    date: date,
    time: '20:00',
    homeTeam: home,
    awayTeam: away,
    venue: 'Some Hall',
    result: result,
  );
}

void main() {
  group('GameModel.didTeamWin', () {
    final us = _team('1');
    final them = _team('2');

    test('returns true when the home team wins', () {
      final g = _game(home: us, away: them, result: '3 - 1');
      expect(g.didTeamWin('1'), true);
      expect(g.didTeamWin('2'), false);
    });

    test('returns true when the away team wins', () {
      final g = _game(home: them, away: us, result: '0 - 3');
      expect(g.didTeamWin('1'), true);
      expect(g.didTeamWin('2'), false);
    });

    test('returns null when the match has not been played', () {
      final g = _game(home: us, away: them, result: '');
      expect(g.didTeamWin('1'), null);
    });

    test('returns null for a team that did not play in this match', () {
      final g = _game(home: us, away: them, result: '3 - 1');
      expect(g.didTeamWin('999'), null);
    });

    test('returns null for an unparsable or tied result', () {
      final tied = _game(home: us, away: them, result: '2 - 2');
      expect(tied.didTeamWin('1'), null);

      final garbled = _game(home: us, away: them, result: 'n/a');
      expect(garbled.didTeamWin('1'), null);
    });
  });

  group('currentStreak', () {
    final us = _team('1');
    final them = _team('2');

    test('null when no matches have been played', () {
      final team = TeamModel(
        label: 'us',
        teamId: '1',
        games: [_game(home: us, away: them, result: '')],
      );
      expect(team_stats.currentStreak(team), null);
    });

    test('counts consecutive wins from the most recent match backwards', () {
      final team = TeamModel(
        label: 'us',
        teamId: '1',
        games: [
          _game(home: us, away: them, result: '1 - 3'), // loss (oldest)
          _game(home: us, away: them, result: '3 - 0'), // win
          _game(home: us, away: them, result: '3 - 1'), // win
          _game(home: us, away: them, result: ''), // unplayed, skipped
        ],
      );

      final streak = team_stats.currentStreak(team);
      expect(streak?.isWin, true);
      expect(streak?.count, 2);
    });

    test('stops counting at the first break in the streak', () {
      final team = TeamModel(
        label: 'us',
        teamId: '1',
        games: [
          _game(home: us, away: them, result: '3 - 0'), // win (oldest)
          _game(home: us, away: them, result: '1 - 3'), // loss
          _game(home: us, away: them, result: '1 - 3'), // loss (most recent)
        ],
      );

      final streak = team_stats.currentStreak(team);
      expect(streak?.isWin, false);
      expect(streak?.count, 2);
    });
  });

  group('date_utils.parseMatchDate', () {
    test('parses a valid DD/MM/YYYY date', () {
      final parts = date_utils.parseMatchDate('12/09/2026');
      expect(parts?['day'], 'Za');
      expect(parts?['dayNum'], 12);
      expect(parts?['month'], 'sep');
    });

    test('returns null for a malformed date', () {
      expect(date_utils.parseMatchDate('not-a-date'), null);
      expect(date_utils.parseMatchDate('12/09'), null);
    });
  });

  group('date_utils.formatDateFull', () {
    test('formats a DD/MM/YYYY date as "Day Num month"', () {
      expect(date_utils.formatDateFull('12/09/2026'), 'Za 12 sep');
    });
  });
}
