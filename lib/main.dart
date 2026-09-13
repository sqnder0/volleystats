import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'match_card.dart';
import 'search_item_club.dart';
import 'search_item_team.dart';
import 'favorite_team_card.dart';
import 'favorite_club_card.dart';
import 'club_team_row.dart';
import 'team_detail_match_card.dart';
import 'ranking_row.dart';
import 'stat_card.dart';
import 'info_card.dart';
import 'settings_row.dart';
import 'toggle_switch.dart';
import 'filter_tab.dart';
import 'toggle_tabs.dart';
import 'date_divider.dart';
import 'empty_state.dart';
import 'toast_overlay.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:convert';
import 'dart:io';
import 'favorite_service.dart';
import 'favorite_clubs_service.dart';
import 'date_utils.dart' as date_utils;
import 'team_stats.dart' as team_stats;
import 'entity_cache.dart';
import 'logger.dart';
import 'network_error.dart';
import 'notification_service.dart';
import 'theme_service.dart';
import 'persistence_service.dart';
import 'results_watcher_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:share_plus/share_plus.dart';

const String apiBaseUrl = "https://volleyapi.sqnder.dev/";
// const String apiBaseUrl = "http://192.168.1.43:8000/";
const String dot = "\u00B7";

// ============================================================
// CACHE
// ============================================================
final _clubCache = EntityCache<ClubModel>(
  maxSize: 50,
  persist: PersistenceService.saveClubs,
  toJson: (c) => c.toJson(),
);
final _teamCache = EntityCache<TeamModel>(
  maxSize: 100,
  persist: PersistenceService.saveTeams,
  toJson: (t) => t.toJson(),
  persistDelay: const Duration(seconds: 3),
);

// ============================================================
// Main
// ============================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VolleyStatsApp());
}

/// Entry point for the periodic Android background task that checks for
/// new results. Runs in its own background isolate, so it re-initializes
/// the notification plugin for that isolate before doing any work.
@pragma('vm:entry-point')
void _resultsWatcherCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await NotificationService.init();
    await ResultsWatcherService.checkForNewResults();
    return true;
  });
}

Future<void> _initApp() async {
  // Initialize in parallel for faster startup
  await Future.wait([
    ThemeService.init(),
    NotificationService.init(),
    _loadPersistentCaches(),
  ]);

  // Start pre-loading favorites in background
  FavoritesService.preloadFavorites();

  // Best-effort periodic result check. Android's WorkManager can run this
  // while the app is closed; iOS has no equivalent without extra native
  // setup, so there we rely on the app-resume check instead (see
  // _VolleyStatsAppState).
  if (Platform.isAndroid) {
    await Workmanager().initialize(_resultsWatcherCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'results-watcher',
      'checkForNewResults',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

Future<void> _loadPersistentCaches() async {
  try {
    final clubsJson = await PersistenceService.loadClubs();
    clubsJson.forEach((key, value) {
      _clubCache.restore(key, ClubModel.fromJson(value as Map<String, dynamic>));
    });

    final teamsJson = await PersistenceService.loadTeams();
    teamsJson.forEach((key, value) {
      _teamCache.restore(key, TeamModel.fromJson(value as Map<String, dynamic>));
    });

    log('Cache', 'Persistent caches loaded successfully');
  } catch (e) {
    log('Cache', 'Error loading persistent caches', error: e);
  }
}

class VolleyStatsApp extends StatefulWidget {
  const VolleyStatsApp({super.key});

  @override
  State<VolleyStatsApp> createState() => _VolleyStatsAppState();
}

class _VolleyStatsAppState extends State<VolleyStatsApp>
    with WidgetsBindingObserver {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The reliable cross-platform path: whenever the user actually opens
      // the app, check favorites for new results. The WorkManager task in
      // _initApp covers the Android-closed-app case on top of this.
      ResultsWatcherService.checkForNewResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final isLoaded = snapshot.connectionState == ConnectionState.done;

        return ValueListenableBuilder<bool>(
          valueListenable: ThemeService.darkModeNotifier,
          builder: (context, isDarkMode, child) {
            return MaterialApp(
              title: 'VolleyStats',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                scaffoldBackgroundColor: primary,
                fontFamily: 'DM Sans',
                brightness: isDarkMode ? Brightness.dark : Brightness.light,
              ),
              home: isLoaded ? const MainShell() : const VLoadingPage(),
            );
          },
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      const SearchPage(),
      const RankingsPage(),
      const FavoritesPage(),
      const MorePage(),
    ];
    ThemeService.darkModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.darkModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(color: primary),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0),
            _buildNavItem(Icons.search_rounded, 'Zoeken', 1),
            _buildNavItem(Icons.emoji_events_rounded, 'Ranking', 2),
            _buildNavItem(Icons.star_rounded, 'Favorieten', 3),
            _buildNavItem(Icons.more_horiz_rounded, 'Meer', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? accentYellow.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? accentYellow : secondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? accentYellow : secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _filter = 'all';
  late Future<List<Map<String, dynamic>>> _homeMatchesFuture;
  List<String> _failedFavoriteNames = [];

  @override
  void initState() {
    super.initState();
    _loadHomeMatches();
    FavoritesService.favoritesNotifier.addListener(_loadHomeMatches);
  }

  @override
  void dispose() {
    FavoritesService.favoritesNotifier.removeListener(_loadHomeMatches);
    super.dispose();
  }

  void _loadHomeMatches({bool forceReload = false}) {
    setState(() {
      _homeMatchesFuture = _fetchHomeMatches(forceReload: forceReload);
    });
  }

  Future<void> _handleRefresh() async {
    _loadHomeMatches(forceReload: true);
    await _homeMatchesFuture;
  }

  Future<List<Map<String, dynamic>>> _fetchHomeMatches({
    bool forceReload = false,
  }) async {
    final favorites = await FavoritesService.loadFavorites();
    final List<String> failedNames = [];
    if (favorites.isEmpty) {
      if (mounted) setState(() => _failedFavoriteNames = []);
      return [];
    }

    final List<Map<String, dynamic>> allMatches = [];
    final Set<String> matchCodes = {};

    for (var favTeam in favorites) {
      try {
        final fullTeam = await favTeam.load(forceReload: forceReload);
        for (var game in fullTeam.games) {
          if (!matchCodes.contains(game.matchCode)) {
            matchCodes.add(game.matchCode);
            allMatches.add({
              'home_team': game.homeTeam.name,
              'away_team': game.awayTeam.name,
              'result': game.result,
              'venue': game.venue,
              'league_name': fullTeam.leagueName,
              'time': game.date, // DD/MM/YYYY
              'match_time': game.time,
              'is_fav_home': game.homeTeam.teamId == favTeam.teamId,
              'favorite_won': game.didTeamWin(favTeam.teamId),
              'fav_name': fullTeam.name,
              'team_model': fullTeam,
              'date_obj': _parseDate(game.date),
            });
          }
        }
      } catch (e) {
        log('HomePage', 'Error loading home matches for ${favTeam.label}', error: e);
        failedNames.add(favTeam.name.isNotEmpty ? favTeam.name : favTeam.label);
      }
    }

    if (mounted) setState(() => _failedFavoriteNames = failedNames);

    // Sort by date and then time
    allMatches.sort((a, b) {
      final dateA = a['date_obj'] as DateTime;
      final dateB = b['date_obj'] as DateTime;
      int cmp = dateA.compareTo(dateB);
      if (cmp != 0) return cmp;
      return (a['match_time'] as String).compareTo(b['match_time'] as String);
    });

    return allMatches;
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (e) {
      return DateTime.now();
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> matches) {
    if (_filter == 'all') return matches;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_filter == 'week') {
      final nextWeek = today.add(const Duration(days: 7));
      return matches.where((m) {
        final d = m['date_obj'] as DateTime;
        return (d.isAtSameMomentAs(today) || d.isAfter(today)) &&
            d.isBefore(nextWeek);
      }).toList();
    }

    if (_filter == 'month') {
      final nextMonth = today.add(const Duration(days: 30));
      return matches.where((m) {
        final d = m['date_obj'] as DateTime;
        return (d.isAtSameMomentAs(today) || d.isAfter(today)) &&
            d.isBefore(nextMonth);
      }).toList();
    }

    return matches;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: accentYellow,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VolleyStats', style: VTextStyles.h1),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Filters
                Row(
                  children: [
                    VFilterTab(
                      label: 'Alles',
                      isActive: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    VFilterTab(
                      label: 'Deze week',
                      isActive: _filter == 'week',
                      onTap: () => setState(() => _filter = 'week'),
                    ),
                    const SizedBox(width: 8),
                    VFilterTab(
                      label: 'Deze maand',
                      isActive: _filter == 'month',
                      onTap: () => setState(() => _filter = 'month'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_failedFavoriteNames.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: accentRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kon wedstrijden niet laden voor: '
                            '${_failedFavoriteNames.join(', ')}',
                            style: VTextStyles.captionBold.copyWith(
                              color: accentRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _homeMatchesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(color: accentYellow),
                    ),
                  ),
                );
              }

              final matches = snapshot.data ?? [];
              if (matches.isEmpty) {
                return const SliverToBoxAdapter(
                  child: VEmptyState(
                    icon: Icons.sports_volleyball_outlined,
                    title: 'Geen wedstrijden',
                    subtitle:
                        'Volg teams om hun wedstrijden hier te zien verschijnen.',
                  ),
                );
              }

              final filtered = _applyFilter(matches);
              if (filtered.isEmpty) {
                return const SliverToBoxAdapter(
                  child: VEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Geen wedstrijden',
                    subtitle: 'Geen wedstrijden gevonden voor deze periode.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: _buildSliverMatchList(filtered),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSliverMatchList(List<Map<String, dynamic>> matches) {
    final List<Map<String, dynamic>> items = [];
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var m in matches) {
      final dateKey = m['time'];
      grouped.putIfAbsent(dateKey, () => []).add(m);
    }

    for (var entry in grouped.entries) {
      // Header item
      items.add({
        'type': 'header',
        'label': entry.key,
        'count': entry.value.length,
      });
      // Match items
      for (var m in entry.value) {
        items.add({'type': 'match', 'data': m});
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        if (item['type'] == 'header') {
          return VDateDivider(
            label: date_utils.formatDateFull(item['label']),
            countLabel: '${item['count']} wed.',
          );
        } else {
          final m = item['data'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VMatchCard(
              homeTeam: m['home_team'],
              awayTeam: m['away_team'],
              result: m['result'],
              venue: m['venue'],
              leagueName: m['league_name'],
              time: m['match_time'],
              isFavTeamHome: m['is_fav_home'] == true,
              showFavBorder: true,
              favoriteWon: m['favorite_won'] as bool?,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamDetailPage(
                    team: m['team_model'],
                    preLoadName: m['fav_name'],
                  ),
                ),
              ),
            ),
          );
        }
      }, childCount: items.length),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  bool _isLoading = false;
  bool _isOffline = false;
  List<ClubModel> _apiClubs = [];
  List<TeamModel> _apiTeams = [];

  @override
  void initState() {
    super.initState();
    ThemeService.darkModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.darkModeNotifier.removeListener(_onThemeChanged);
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _controller.clear();
    _onSearchChanged('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _performSearch(String query) async {
    // Guards against a slow, now-stale request overwriting results for
    // whatever the user has since typed.
    bool isStale() => !mounted || _query != query;

    if (query.length < 2) {
      setState(() {
        _apiClubs = [];
        _apiTeams = [];
        _isLoading = false;
        _isOffline = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      // Proactive connectivity check
      try {
        final result = await InternetAddress.lookup('volleyapi.sqnder.dev');
        if (result.isEmpty || result.first.address.isEmpty) {
          throw const SocketException('No address found');
        }
      } catch (_) {
        if (isStale()) return;
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
        return;
      }

      final uri = Uri.parse(
        '${apiBaseUrl}api/search?q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (isStale()) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final clubsJson = data['clubs'] as List<dynamic>?;
        final teamsJson = data['teams'] as List<dynamic>?;

        final clubs =
            clubsJson
                ?.map((c) => ClubModel.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [];
        final teams =
            teamsJson
                ?.map((t) => TeamModel.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [];

        // Check favorites
        final favs = await FavoritesService.loadFavorites();
        if (isStale()) return;
        final favIds = favs.map((f) => f.teamId).toSet();
        for (var t in teams) {
          t.isFavorite = favIds.contains(t.teamId);
        }

        setState(() {
          _apiClubs = clubs;
          _apiTeams = teams;
          _isLoading = false;
          _isOffline = false;
        });
      } else {
        log('SearchPage', 'API error ${response.statusCode}: ${response.body}');
        setState(() => _isLoading = false);
        VToastOverlay.show(
          context,
          'Fout bij het laden: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (isStale()) return;
      log('SearchPage', 'Search failed', error: e);
      setState(() {
        _isLoading = false;
        if (isOffline(e)) {
          _isOffline = true;
        }
      });
      if (!_isOffline) {
        VToastOverlay.show(context, 'Kon geen verbinding maken');
      }
    }
  }

  void _onSearchChanged(String query) {
    _query = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text('Zoeken', style: VTextStyles.h2),
        const SizedBox(height: 2),
        Text('Zoek clubs en teams', style: VTextStyles.caption),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          onChanged: _onSearchChanged,
          style: VTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Club of team zoeken...',
            hintStyle: VTextStyles.caption,
            prefixIcon: Icon(Icons.search, size: 14, color: secondary),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(Icons.close, size: 16, color: secondary),
                    ),
                  )
                : null,
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: accentYellow),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_isLoading) ...[
          const SizedBox(height: 60),
          const Center(child: CircularProgressIndicator(color: accentYellow)),
        ] else if (_isOffline) ...[
          Center(
            child: VEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Je bent offline',
              subtitle: 'Controleer je verbinding om te kunnen zoeken.',
              actionLabel: 'Opnieuw proberen',
              onActionTap: () => _performSearch(_query),
            ),
          ),
        ] else if (_query == '') ...[
          Center(
            child: VEmptyState(
              icon: Icons.search,
              title: 'Zoek clubs of teams',
              subtitle: 'Type iets om te beginnen (bv: Mendo)',
            ),
          ),
        ] else ...[
          if (_apiClubs.isNotEmpty) ...[
            Text('CLUBS (${_apiClubs.length})', style: VTextStyles.smallLabel),
            const SizedBox(height: 8),
            ..._apiClubs.map(
              (c) => VSearchItemClub(
                name: c.name,
                clubCode: c.code,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClubDetailPage(club: c)),
                ),
              ),
            ),
          ],
          if (_apiTeams.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('TEAMS (${_apiTeams.length})', style: VTextStyles.smallLabel),
            const SizedBox(height: 8),
            ..._apiTeams.map(
              (t) => VSearchItemTeam(
                name: t.name,
                leagueName: t.leagueName,
                isFavorite: t.isFavorite,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TeamDetailPage(team: t, preLoadName: t.name),
                  ),
                ),
                onFavoriteTap: () async {
                  final newStatus = await FavoritesService.toggleFavorite(t);
                  setState(() {
                    t.isFavorite = newStatus;
                  });
                  if (mounted) {
                    VToastOverlay.show(
                      context,
                      newStatus
                          ? 'Toegevoegd aan favorieten'
                          : 'Verwijderd uit favorieten',
                    );
                  }
                },
              ),
            ),
          ],
          if (_apiClubs.isEmpty && _apiTeams.isEmpty)
            Center(
              child: VEmptyState(
                icon: Icons.search,
                title: 'Geen resultaten voor "$_query"',
                subtitle: 'Probeer een andere zoekterm.',
              ),
            ),
        ],
      ],
    );
  }
}

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  List<TeamModel> _favoriteTeams = [];
  TeamModel? _selectedFavoriteTeam;
  bool _isLoadingLeagues = true;
  bool _isLoadingRanking = false;
  String? _error;
  final List<String> _favTeamNames = [];

  @override
  void initState() {
    super.initState();
    _initializeLeagues();
    FavoritesService.favoritesNotifier.addListener(_onFavoritesChanged);
    ThemeService.darkModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    FavoritesService.favoritesNotifier.removeListener(_onFavoritesChanged);
    ThemeService.darkModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onFavoritesChanged() {
    if (mounted) {
      _initializeLeagues();
    }
  }

  Future<void> _initializeLeagues() async {
    setState(() {
      _isLoadingLeagues = true;
      _error = null;
    });

    try {
      final favorites = await FavoritesService.loadFavorites();
      if (favorites.isEmpty) {
        setState(() {
          _isLoadingLeagues = false;
          _favoriteTeams = [];
        });
        return;
      }

      final Set<TeamModel> loadedFavs = {};
      _favTeamNames.clear();

      for (var team in favorites) {
        // Ensure team is loaded to have league info and name
        final fullTeam = await team.load();
        loadedFavs.add(fullTeam);
        _favTeamNames.add(fullTeam.name);
      }

      setState(() {
        _favoriteTeams = loadedFavs.toList();

        // Ensure the selected team is still in the list (or pick first)
        if (_selectedFavoriteTeam == null ||
            !loadedFavs.contains(_selectedFavoriteTeam)) {
          _selectedFavoriteTeam = loadedFavs.isNotEmpty
              ? loadedFavs.first
              : null;
        } else {
          // Keep current selection instance from the new list
          _selectedFavoriteTeam = loadedFavs.lookup(_selectedFavoriteTeam);
        }

        _isLoadingLeagues = false;

        if (_selectedFavoriteTeam != null) {
          _loadRanking();
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingLeagues = false;
        _error = "Kon leagues niet laden: $e";
      });
    }
  }

  Future<void> _loadRanking({bool forceReload = false}) async {
    if (_selectedFavoriteTeam == null) return;

    setState(() {
      _isLoadingRanking = true;
      _error = null;
    });

    try {
      // Re-load the team to get fresh ranking data if needed
      await _selectedFavoriteTeam!.load(forceReload: forceReload);

      setState(() {
        _isLoadingRanking = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRanking = false;
        _error = "Kon ranking niet laden: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLeagues) {
      return const Center(
        child: CircularProgressIndicator(color: accentYellow),
      );
    }

    if (_favoriteTeams.isEmpty) {
      return Center(
        child: VEmptyState(
          icon: Icons.star_border,
          title: 'Geen favorieten',
          subtitle: 'Volg eerst teams om rankings te bekijken.',
          actionLabel: 'Zoeken',
          onActionTap: () {
            // In the real app, we'd navigate to search.
            _initializeLeagues();
          },
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ranking', style: VTextStyles.h2),
              const SizedBox(height: 16),
              // Favorite Teams Dropdown
              Text('MIJN TEAMS', style: VTextStyles.smallLabel),
              const SizedBox(height: 8),
              DropdownButtonFormField<TeamModel>(
                initialValue: _selectedFavoriteTeam,
                dropdownColor: cardBg,
                style: VTextStyles.body,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: accentYellow),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                items: _favoriteTeams
                    .map(
                      (t) => DropdownMenuItem<TeamModel>(
                        value: t,
                        child: Text(
                          t.name.isNotEmpty ? t.name : t.label,
                          style: VTextStyles.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedFavoriteTeam = v;
                    });
                    _loadRanking();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_error != null) {
      return Center(
        child: VEmptyState(
          icon: Icons.error_outline,
          title: 'Fout bij laden',
          subtitle: _error,
          actionLabel: 'Opnieuw proberen',
          onActionTap: _loadRanking,
        ),
      );
    }

    if (_selectedFavoriteTeam == null) {
      return Center(
        child: VEmptyState(
          icon: Icons.info_outline,
          title: 'Geen team geselecteerd',
          subtitle: 'Selecteer een team om de ranking te bekijken.',
          actionLabel: 'Vernieuwen',
          onActionTap: _initializeLeagues,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRanking(forceReload: true),
      color: accentYellow,
      backgroundColor: cardBg,
      child: _buildRankingContent(),
    );
  }

  Widget _buildRankingContent() {
    if (_isLoadingRanking) {
      return const Center(
        child: CircularProgressIndicator(color: accentYellow),
      );
    }

    final team = _selectedFavoriteTeam;
    if (team == null) return const SizedBox.shrink();

    final ranking = team.ranking;
    final alert = team.rankingAlert;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        if (alert != null && alert.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: accentYellow.withValues(
                alpha: ThemeService.isDarkMode ? 0.1 : 0.15,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentYellow.withValues(
                  alpha: ThemeService.isDarkMode ? 0.3 : 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: accentYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert,
                    style: VTextStyles.captionBold.copyWith(color: alertGold),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          child: Column(
            children: [
              if (ranking.isNotEmpty)
                const VRankingRow(
                  position: '#',
                  teamName: '',
                  wins: 0,
                  losses: 0,
                  setsWon: 0,
                  setsLost: 0,
                  points: 0,
                  isHeader: true,
                ),
              if (ranking.isEmpty && (alert == null || alert.isEmpty))
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 40,
                        color: secondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Geen rangschikking gevonden',
                        style: VTextStyles.bodyBold.copyWith(color: secondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Het seizoen is mogelijk nog niet gestart.',
                        style: VTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ...ranking.map((r) {
                final String teamName = r['team'] ?? '';
                final int wins =
                    (r['won_3_0_3_1'] as num? ?? 0).toInt() +
                    (r['won_3_2'] as num? ?? 0).toInt();
                final int losses =
                    (r['lost_3_0_3_1'] as num? ?? 0).toInt() +
                    (r['lost_3_2'] as num? ?? 0).toInt();

                return VRankingRow(
                  position: r['position']?.toString() ?? '',
                  teamName: teamName,
                  wins: wins,
                  losses: losses,
                  setsWon: (r['sets_won'] as num? ?? 0).toInt(),
                  setsLost: (r['sets_lost'] as num? ?? 0).toInt(),
                  points: (r['points'] as num? ?? 0).toInt(),
                  isFavorite: _favTeamNames.contains(teamName),
                );
              }),
            ],
          ),
        ),
        if (ranking.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accentYellow.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: accentYellow),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Favoriet', style: VTextStyles.dateSmall),
                ],
              ),
              const SizedBox(width: 16),
              Text(
                'W = Gewonnen · V = Verloren · S = Sets',
                style: VTextStyles.dateSmall,
              ),
            ],
          ),
        ],
        const SizedBox(height: 40), // Spacing for pull-to-refresh
      ],
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<TeamModel>> _favoritesFuture;
  late Future<List<ClubModel>> _favoriteClubsFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadFavoriteClubs();
    FavoritesService.favoritesNotifier.addListener(_loadFavorites);
    FavoriteClubsService.favoriteClubsNotifier.addListener(_loadFavoriteClubs);
  }

  @override
  void dispose() {
    FavoritesService.favoritesNotifier.removeListener(_loadFavorites);
    FavoriteClubsService.favoriteClubsNotifier.removeListener(
      _loadFavoriteClubs,
    );
    super.dispose();
  }

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = FavoritesService.loadFavorites();
    });
  }

  void _loadFavoriteClubs() {
    setState(() {
      _favoriteClubsFuture = FavoriteClubsService.loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Favorieten', style: VTextStyles.h2),
              const SizedBox(height: 2),
              Text('Je gevolgde teams', style: VTextStyles.caption),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ClubModel>>(
            future: _favoriteClubsFuture,
            builder: (context, clubsSnapshot) {
              final clubs = clubsSnapshot.data ?? [];

              return FutureBuilder<List<TeamModel>>(
                future: _favoritesFuture,
                builder: (context, teamsSnapshot) {
                  final teamsLoading =
                      teamsSnapshot.connectionState ==
                      ConnectionState.waiting;
                  final favorites = teamsSnapshot.data ?? [];

                  if (!teamsLoading && favorites.isEmpty && clubs.isEmpty) {
                    return const Center(
                      child: VEmptyState(
                        icon: Icons.star_border,
                        title: 'Geen favorieten',
                        subtitle:
                            'Voeg clubs of teams toe aan je favorieten om ze hier te bekijken.',
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    children: [
                      if (clubs.isNotEmpty) ...[
                        Text('CLUBS', style: VTextStyles.smallLabel),
                        const SizedBox(height: 8),
                        ...clubs.map(
                          (club) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FutureBuilder<ClubModel>(
                              future: club.load(),
                              builder: (context, clubSnapshot) {
                                final fullClub = clubSnapshot.data;

                                return VFavoriteClubCard(
                                  clubName: club.label,
                                  competitionTeamCount:
                                      fullClub?.compTeams.length,
                                  cupTeamCount: fullClub?.cupTeams.length,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ClubDetailPage(club: club),
                                    ),
                                  ),
                                  onRemoveTap: () async {
                                    await FavoriteClubsService.removeFavorite(
                                      club.clubId,
                                    );
                                    _loadFavoriteClubs();
                                    if (context.mounted) {
                                      VToastOverlay.show(
                                        context,
                                        'Club verwijderd uit favorieten',
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (favorites.isNotEmpty || teamsLoading) ...[
                        Text('TEAMS', style: VTextStyles.smallLabel),
                        const SizedBox(height: 8),
                        if (teamsLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          ...favorites.map((savedTeam) {
                            return FutureBuilder<TeamModel>(
                              future: savedTeam.load(),
                              builder: (context, teamSnapshot) {
                                if (!teamSnapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: VClubTeamRow.loading(),
                                  );
                                }

                                final fullTeam = teamSnapshot.data!;
                                final upcoming = fullTeam.games
                                    .where((g) => g.result.isEmpty)
                                    .toList();
                                final hasMatch = upcoming.isNotEmpty;
                                final nextMatch = hasMatch
                                    ? upcoming.first
                                    : null;
                                final dateParts = nextMatch != null
                                    ? date_utils.parseMatchDate(nextMatch.date)
                                    : null;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: VFavoriteTeamCard(
                                    teamName: fullTeam.name,
                                    leagueName: fullTeam.leagueName,
                                    hasUpcomingMatch: hasMatch,
                                    nextHomeTeam: nextMatch?.homeTeam.name,
                                    nextAwayTeam: nextMatch?.awayTeam.name,
                                    nextTime: nextMatch?.time,
                                    nextDateDay: dateParts?['day'],
                                    nextDateDayNum: dateParts?['dayNum'],
                                    nextDateMonth: dateParts?['month'],
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeamDetailPage(
                                          team: fullTeam,
                                          preLoadName: fullTeam.name,
                                        ),
                                      ),
                                    ),
                                    onRemoveTap: () async {
                                      await FavoritesService.removeFavorite(
                                        fullTeam.teamId,
                                      );
                                      _loadFavorites();
                                      if (context.mounted) {
                                        VToastOverlay.show(
                                          context,
                                          'Team verwijderd uit favorieten',
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          }),
                      ] else if (clubs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Nog geen team favorieten.',
                            style: VTextStyles.caption,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool _notificationsEnabled = false;
  bool _resultNotificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await FavoritesService.areNotificationsEnabled();
    final resultEnabled =
        await FavoritesService.areResultNotificationsEnabled();
    final time = await FavoritesService.getNotificationTime();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _resultNotificationsEnabled = resultEnabled;
        _notificationTime = time;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    await FavoritesService.setNotificationsEnabled(value);
    setState(() => _notificationsEnabled = value);
    if (value) {
      // Trigger a re-load to schedule notifications
      FavoritesService.preloadFavorites();
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> _toggleResultNotifications(bool value) async {
    await FavoritesService.setResultNotificationsEnabled(value);
    setState(() => _resultNotificationsEnabled = value);
    if (value) {
      // Seed/refresh the baseline immediately rather than waiting for the
      // next periodic check or app resume.
      ResultsWatcherService.checkForNewResults();
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    await ThemeService.setDarkMode(value);
    setState(
      () => _notificationsEnabled = _notificationsEnabled,
    ); // Trigger rebuild for toggle switch visual
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentYellow,
              onPrimary: primary,
              surface: cardBg,
              onSurface: light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await FavoritesService.setNotificationTime(picked);
      setState(() => _notificationTime = picked);
      // Trigger a re-load to reschedule notifications
      FavoritesService.preloadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text('Meer', style: VTextStyles.h2),
        const SizedBox(height: 24),

        // Instellingen
        VSettingsRow(
          icon: Icons.notifications_outlined,
          iconBgColor: accentRed.withValues(alpha: 0.12),
          iconColor: accentRed,
          title: 'Notificaties',
          subtitle: 'Dagelijks overzicht van wedstrijden',
          trailing: VToggleSwitch(isOn: _notificationsEnabled),
          onTap: () => _toggleNotifications(!_notificationsEnabled),
        ),
        if (_notificationsEnabled)
          VSettingsRow(
            icon: Icons.access_time_rounded,
            iconBgColor: accentYellow.withValues(
              alpha: ThemeService.isDarkMode ? 0.12 : 0.2,
            ),
            iconColor: accentYellow,
            title: 'Tijdstip melding',
            subtitle:
                'Ontvang het overzicht om ${_notificationTime.format(context)}',
            onTap: _pickTime,
          ),
        VSettingsRow(
          icon: Icons.sports_volleyball_outlined,
          iconBgColor: accentGreen.withValues(alpha: 0.12),
          iconColor: accentGreen,
          title: 'Resultaat meldingen',
          subtitle: Platform.isIOS
              ? 'Melding bij een nieuwe uitslag (niet gegarandeerd als de app gesloten is)'
              : 'Melding bij een nieuwe uitslag van je favoriete teams',
          trailing: VToggleSwitch(isOn: _resultNotificationsEnabled),
          onTap: () => _toggleResultNotifications(!_resultNotificationsEnabled),
        ),
        VSettingsRow(
          icon: Icons.dark_mode_outlined,
          iconBgColor: blueInfo.withValues(alpha: 0.12),
          iconColor: blueInfo,
          title: 'Donkere Modus',
          subtitle: ThemeService.isDarkMode ? 'Altijd aan' : 'Uitgeschakeld',
          trailing: VToggleSwitch(
            isOn: ThemeService.isDarkMode,
            onChanged: _toggleDarkMode,
          ),
          onTap: () => _toggleDarkMode(!ThemeService.isDarkMode),
        ),
        const SizedBox(height: 24),

        // Over
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'VolleyStats',
                style: VTextStyles.h3.copyWith(color: accentYellow),
              ),
              const SizedBox(height: 4),
              Text('Flemish Volleyball Stats', style: VTextStyles.caption),
              const SizedBox(height: 8),
              Text(
                'Data provided by Volleyscores. Data is as is.',
                style: VTextStyles.dateSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://volleyscores.be');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cardBgAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.open_in_new,
                        size: 11,
                        color: accentYellow,
                      ),
                      const SizedBox(width: 6),
                      Text('volleyscores.be', style: VTextStyles.bodyBold),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Versie 0.0.1 · Made with ❤️ by Sander Pelgrims',
                style: VTextStyles.dateSmall,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon(Icons.language, 'Website', 'https://sqnder.dev'),
                  const SizedBox(width: 16),
                  _socialIcon(
                    Icons.camera_alt_outlined,
                    'Instagram',
                    'https://instagram.com/sander_pelgrims',
                  ),
                  const SizedBox(width: 16),
                  _socialIcon(
                    Icons.link,
                    'LinkedIn',
                    'https://linkedin.com/in/sanderpelgrims',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _socialIcon(IconData icon, String name, String url) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cardBgAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: secondary),
          ),
        );
      },
    );
  }
}

class ClubDetailPage extends StatefulWidget {
  final ClubModel club;
  const ClubDetailPage({super.key, required this.club});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> {
  bool _isCompetitionTab = true;
  bool _isFavorite = false;
  late Future<ClubModel> _clubFuture;
  final Map<String, TeamModel> _loadedTeams = {};

  @override
  void initState() {
    super.initState();
    _clubFuture = widget.club.load();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final isFav = await FavoriteClubsService.isFavorite(widget.club.clubId);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _handleRefresh() async {
    final freshClub = await widget.club.load(forceReload: true);

    // Reload every visible team's row data up front and populate the cache
    // directly, rather than flipping a "force reload" flag that the team
    // FutureBuilders read at build time - by the time this function's
    // `await` above resumes and could reset such a flag, the outer
    // FutureBuilder here has *already* rebuilt (its own internal listener
    // on the same future runs after this one, since it only subscribes on
    // the next frame - after this continuation, not before), so a
    // flag-based approach silently reads back `false` and never actually
    // re-fetches team data.
    final allTeams = [...freshClub.compTeams, ...freshClub.cupTeams];
    await Future.wait(
      allTeams.map((team) async {
        try {
          final loaded = await team.load(forceReload: true);
          loaded.isFavorite = await FavoritesService.isFavorite(
            loaded.teamId,
          );
          _loadedTeams[loaded.teamId] = loaded;
        } catch (e) {
          log('ClubDetailPage', 'Refresh failed for team ${team.teamId}', error: e);
        }
      }),
    );

    if (mounted) {
      setState(() {
        _clubFuture = Future.value(freshClub);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.chevron_left, color: light, size: 16),
          ),
        ),
        title: FutureBuilder(
          future: _clubFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                "Loading...",
                style: VTextStyles.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }

            if (snapshot.hasError) {
              log('ClubDetailPage', 'Club future failed', error: snapshot.error);
              debugPrintStack(stackTrace: snapshot.stackTrace);
              return Text("Error", style: VTextStyles.h3);
            }

            final club = snapshot.data;

            if (club == null) {
              return Text("No data", style: VTextStyles.h3);
            }

            return Text(
              club.name,
              style: VTextStyles.h3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final newStatus = await FavoriteClubsService.toggleFavorite(
                  widget.club,
                );
                setState(() => _isFavorite = newStatus);
                if (mounted) {
                  VToastOverlay.show(
                    context,
                    newStatus
                        ? 'Toegevoegd aan favorieten'
                        : 'Verwijderd uit favorieten',
                  );
                }
              },
              child: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                size: 18,
                color: accentYellow,
              ),
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: accentYellow,
        child: FutureBuilder<ClubModel>(
          future: _clubFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              final offline = error != null && isOffline(error);

              return Center(
                child: VEmptyState(
                  icon: offline
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline,
                  title: offline ? 'Je bent offline' : 'Fout bij laden',
                  subtitle: offline
                      ? 'Controleer je verbinding om de clubgegevens te bekijken.'
                      : 'We konden de clubgegevens niet ophalen.',
                  actionLabel: 'Opnieuw proberen',
                  onActionTap: () {
                    setState(() {
                      _clubFuture = widget.club.load();
                    });
                  },
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: accentYellow),
              );
            }

            final club = snapshot.data!;

            final compTeams = club.compTeams;
            final cupTeams = club.cupTeams;

            final teamsToShow = _isCompetitionTab ? compTeams : cupTeams;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // INFO CARDS
                Row(
                  children: [
                    Expanded(
                      child: VInfoCard(
                        label: 'Voorzitter',
                        value: club.chairman,
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: VInfoCard(
                        label: 'Secretaris',
                        value: club.secretary,
                        icon: Icons.edit_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                VInfoCard(
                  label: 'Website',
                  value: club.website,
                  icon: Icons.language,
                ),

                const SizedBox(height: 20),

                // TOGGLE
                VToggleTabs(
                  leftLabel: 'Competitie',
                  rightLabel: 'Beker',
                  leftCount: compTeams.length,
                  rightCount: cupTeams.length,
                  isLeftActive: _isCompetitionTab,
                  onLeftTap: () => setState(() => _isCompetitionTab = true),
                  onRightTap: () => setState(() => _isCompetitionTab = false),
                ),

                const SizedBox(height: 16),

                // LIST
                ...teamsToShow.map((team) {
                  final cachedTeam = _loadedTeams[team.teamId];

                  return FutureBuilder<TeamModel>(
                    key: ValueKey('${_isCompetitionTab}_${team.teamId}'),
                    future: cachedTeam != null
                        ? Future.value(cachedTeam)
                        : team.load().then((loaded) async {
                            loaded.isFavorite =
                                await FavoritesService.isFavorite(
                                  loaded.teamId,
                                );
                            _loadedTeams[loaded.teamId] = loaded;
                            return loaded;
                          }),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        log(
                          'ClubDetailPage',
                          'Error loading team ${team.teamId}',
                          error: snapshot.error,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: VClubTeamRow(
                            teamName: 'Fout bij laden',
                            seriesLabel: team.label,
                            onTap: () {
                              setState(() {
                                _loadedTeams.remove(team.teamId);
                              });
                            },
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: VClubTeamRow.loading(),
                        );
                      }

                      final loadedTeam = snapshot.data!;
                      var nextMatchString = "Geen volgende wedstrijd";
                      String? venue;
                      String? lastResultString;
                      bool? lastResultWon;

                      // The schedule table lists every match of the season in
                      // order, so games.first is only "next" before the
                      // season starts - filter to unplayed matches instead of
                      // blindly taking the first one.
                      final upcoming = loadedTeam.games
                          .where((g) => g.result.isEmpty)
                          .toList();
                      if (upcoming.isNotEmpty) {
                        final nextMatch = upcoming.first;
                        venue = nextMatch.venue;
                        int last = nextMatch.date.length;

                        String date = (last == 10)
                            ? nextMatch.date.substring(0, (last - 5))
                            : nextMatch.date;

                        nextMatchString =
                            "$date $dot ${nextMatch.time} $dot"
                            "${nextMatch.homeTeam.name} - "
                            "${nextMatch.awayTeam.name}";
                      }

                      final played = loadedTeam.games
                          .where((g) => g.result.isNotEmpty)
                          .toList();
                      if (played.isNotEmpty) {
                        final lastMatch = played.last;
                        lastResultWon = lastMatch.didTeamWin(loadedTeam.teamId);
                        lastResultString =
                            "${lastMatch.homeTeam.name} ${lastMatch.result} "
                            "${lastMatch.awayTeam.name}";
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: VClubTeamRow(
                          teamName: loadedTeam.name,
                          seriesLabel: loadedTeam.leagueName,
                          nextMatch: nextMatchString,
                          venue: venue,
                          lastResult: lastResultString,
                          lastResultWon: lastResultWon,
                          isFavorite: loadedTeam.isFavorite,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeamDetailPage(
                                team: loadedTeam,
                                preLoadName: loadedTeam.name,
                              ),
                            ),
                          ),
                          onFavoriteTap: () async {
                            final newStatus =
                                await FavoritesService.toggleFavorite(
                                  loadedTeam,
                                );
                            setState(() {
                              loadedTeam.isFavorite = newStatus;
                            });
                            if (mounted) {
                              VToastOverlay.show(
                                context,
                                newStatus ? 'Toegevoegd' : 'Verwijderd',
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TeamDetailPage extends StatefulWidget {
  final TeamModel team;
  final String preLoadName;

  const TeamDetailPage({super.key, required this.team, this.preLoadName = ''});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  late Future<TeamModel> _teamFuture;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _teamFuture = widget.team.load();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final isFav = await FavoritesService.isFavorite(widget.team.teamId);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _teamFuture = widget.team.load(forceReload: true);
    });
    await _teamFuture;
  }

  Future<void> _downloadAndOpenCalendar(
    BuildContext context,
    String url,
    String teamName,
  ) async {
    VToastOverlay.show(context, 'Agenda downloaden...');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        // Create a safe filename
        final safeName = teamName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        final filePath = '${tempDir.path}/$safeName.ics';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFilex.open(filePath, type: 'application/ics');
        if (result.type != ResultType.done) {
          if (context.mounted) {
            VToastOverlay.show(context, 'Kon agenda bestand niet openen');
          }
        }
      } else {
        if (context.mounted) {
          VToastOverlay.show(
            context,
            'Download mislukt: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      log('TeamDetailPage', 'Error syncing calendar', error: e);
      if (context.mounted) {
        VToastOverlay.show(context, 'Fout bij het openen van de agenda');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String preLoadName = widget.preLoadName;

    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.chevron_left, color: light, size: 16),
          ),
        ),
        title: FutureBuilder(
          future: _teamFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text(
                preLoadName,
                style: VTextStyles.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            } else {
              return Text(
                snapshot.data!.name,
                style: VTextStyles.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final newStatus = await FavoritesService.toggleFavorite(
                  widget.team,
                );
                setState(() {
                  _isFavorite = newStatus;
                });
                if (mounted) {
                  VToastOverlay.show(
                    context,
                    newStatus
                        ? 'Toegevoegd aan favorieten'
                        : 'Verwijderd uit favorieten',
                  );
                }
              },
              child: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                size: 18,
                color: accentYellow,
              ),
            ),
          ),
          FutureBuilder<TeamModel>(
            future: _teamFuture,
            builder: (context, snapshot) {
              final team = snapshot.data;
              if (team == null ||
                  team.calendarUrl == null ||
                  team.calendarUrl!.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => _downloadAndOpenCalendar(
                    context,
                    team.calendarUrl!,
                    team.name,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: accentYellow,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: accentYellow,
        child: FutureBuilder<TeamModel>(
          future: _teamFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Center(
                    child: VEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'Wedstrijden laden',
                      subtitle: 'Even geduld, we halen de wedstrijden op...',
                    ),
                  ),
                ],
              );
            }

            if (!snapshot.hasData || snapshot.data!.games.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Center(
                    child: VEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'Geen wedstrijden beschikbaar',
                      subtitle:
                          'De wedstrijdata worden binnenkort bekendgemaakt.',
                    ),
                  ),
                ],
              );
            }

            final team = snapshot.data!;

            final dagen = ['Zo', 'Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za'];
            final maanden = [
              'januari',
              'februari',
              'maart',
              'april',
              'mei',
              'juni',
              'juli',
              'augustus',
              'september',
              'oktober',
              'november',
              'december',
            ];

            final Map<String, Map<String, dynamic>> grouped = {};

            for (final m in team.games) {
              final parts = m.date.split('/');

              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);

              final key = '$month/$year';
              final label = '${maanden[month - 1]} $year';

              grouped.putIfAbsent(
                key,
                () => {'label': label, 'matches': <GameModel>[]},
              );

              (grouped[key]!['matches'] as List<GameModel>).add(m);
            }

            final sections = grouped.entries.toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildStatsRow(team),
                if (team.calendarUrl != null && team.calendarUrl!.isNotEmpty)
                  _buildCalendarSyncCard(context, team.calendarUrl!, team.name),
                ...sections.map((section) {
                  final matches = section.value['matches'] as List<GameModel>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VDateDivider(label: section.value['label'] as String),
                      ...matches.map((m) {
                        final parts = m.date.split('/');
                        final day = int.parse(parts[0]);
                        final month = int.parse(parts[1]);
                        final year = int.parse(parts[2]);

                        final date = DateTime(year, month, day);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: VTeamDetailMatchCard(
                            homeTeam: m.homeTeam.name,
                            awayTeam: m.awayTeam.name,
                            result: m.result,
                            venue: m.venue,
                            dateDay: dagen[date.weekday % 7],
                            dateNum: day,
                            dateMonth: maanden[month - 1].substring(0, 3),
                            timeString: m.time,
                            isHomeTeam: m.homeTeam.teamId == team.teamId,
                            favoriteWon: m.didTeamWin(team.teamId),
                            onTap: m.matchId != null
                                ? () => _showSetScores(context, m)
                                : null,
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Finds this team's own row in its ranking table. The scraper leaves
  /// team_id null for that row (the site doesn't link to the team whose
  /// page you're already on), so it's matched by name instead.
  Map<String, dynamic>? _selfRankingRow(TeamModel team) {
    for (final r in team.ranking) {
      if (r is Map<String, dynamic> && r['team'] == team.name) {
        return r;
      }
    }
    return null;
  }

  Widget _buildStatsRow(TeamModel team) {
    final row = _selfRankingRow(team);
    if (row == null) return const SizedBox.shrink();

    final won =
        ((row['won_3_0_3_1'] as num?) ?? 0).toInt() +
        ((row['won_3_2'] as num?) ?? 0).toInt();
    final lost =
        ((row['lost_3_0_3_1'] as num?) ?? 0).toInt() +
        ((row['lost_3_2'] as num?) ?? 0).toInt();
    final setsWon = ((row['sets_won'] as num?) ?? 0).toInt();
    final setsLost = ((row['sets_lost'] as num?) ?? 0).toInt();
    final points = ((row['points'] as num?) ?? 0).toInt();
    final streak = team_stats.currentStreak(team);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: VStatCard(
                  value: won,
                  label: 'Gewonnen',
                  valueColor: accentGreen,
                  gradientStart: accentGreen.withValues(alpha: 0.12),
                  gradientEnd: accentGreen.withValues(alpha: 0.04),
                  borderColor: accentGreen.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VStatCard(
                  value: lost,
                  label: 'Verloren',
                  valueColor: accentRed,
                  gradientStart: accentRed.withValues(alpha: 0.12),
                  gradientEnd: accentRed.withValues(alpha: 0.04),
                  borderColor: accentRed.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VStatCard(value: setsWon - setsLost, label: 'Sets +/-'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VStatCard(value: points, label: 'Punten'),
              ),
            ],
          ),
          if (streak != null && streak.count >= 2) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  streak.isWin
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14,
                  color: streak.isWin ? accentGreen : accentRed,
                ),
                const SizedBox(width: 4),
                Text(
                  '${streak.count}x op rij ${streak.isWin ? "gewonnen" : "verloren"}',
                  style: VTextStyles.caption,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildShareText(GameModel match, MatchDetailModel? detail) {
    final buffer = StringBuffer(
      '${match.homeTeam.name} ${match.result} ${match.awayTeam.name}',
    );
    if (detail != null && detail.sets.isNotEmpty) {
      final sets = detail.sets.map((s) => '${s.home}-${s.away}').join(', ');
      buffer.write('\n($sets)');
    }
    buffer.write('\n\nVolleyStats');
    return buffer.toString();
  }

  void _showSetScores(BuildContext context, GameModel match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<MatchDetailModel>(
            future: MatchDetailModel.load(match.matchCode, match.matchId!),
            builder: (context, snapshot) {
              final detail = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${match.homeTeam.name} - ${match.awayTeam.name}',
                          style: VTextStyles.h3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => SharePlus.instance.share(
                          ShareParams(text: _buildShareText(match, detail)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: accentYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(match.result, style: VTextStyles.bodySecondary),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: accentYellow),
                      ),
                    )
                  else if (snapshot.hasError || snapshot.data!.sets.isEmpty)
                    Text(
                      'Setstanden niet beschikbaar voor deze wedstrijd.',
                      style: VTextStyles.caption,
                    )
                  else
                    ...snapshot.data!.sets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final set = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Set ${index + 1}', style: VTextStyles.body),
                            Text(
                              '${set.home} - ${set.away}',
                              style: VTextStyles.bodyBold,
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCalendarSyncCard(
    BuildContext context,
    String url,
    String teamName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardBgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _downloadAndOpenCalendar(context, url, teamName),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentYellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: accentYellow,
              size: 20,
            ),
          ),
          title: Text(
            'Team Agenda Synchroniseren',
            style: VTextStyles.bodyBold,
          ),
          subtitle: Text(
            'Voeg alle wedstrijden toe aan je agenda',
            style: VTextStyles.caption,
          ),
          trailing: Icon(Icons.chevron_right, size: 16, color: secondary),
        ),
      ),
    );
  }
}

// ============================================================
// STATISCHE DATA MODELLEN
// ============================================================
class ClubModel {
  final String name;
  final String code;
  final String label;
  final String chairman;
  final String secretary;
  final String website;
  final String clubId;

  final List<TeamModel> compTeams;
  final List<TeamModel> cupTeams;

  const ClubModel({
    required this.label,
    required this.clubId,
    this.name = '',
    this.chairman = '',
    this.secretary = '',
    this.website = '',
    this.code = '',
    this.compTeams = const [],
    this.cupTeams = const [],
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    final general = json['general'] as Map<String, dynamic>? ?? {};

    return ClubModel(
      name: json['name'] ?? '',
      code: json['club_code'] ?? '',
      label: json['label'] ?? '',
      clubId: (json['club_id'] ?? json['id'])?.toString() ?? '',

      chairman: general['Voorzitter']?.toString() ?? '',
      secretary: general['Secretaris']?.toString() ?? '',
      website: general['Website']?.toString() ?? '',

      compTeams:
          (json['competition_teams'] as List?)?.map((m) {
            final String series = m["series"]?.toString() ?? '';
            String leagueCode = '';
            if (series.isNotEmpty) {
              final parts = series.split(" ");
              if (parts.isNotEmpty) leagueCode = parts.last;
            }
            String teamLabel = "${m['team'] ?? ''} ($leagueCode)";
            final teamId =
                (m["id"] ?? m["team_id"] ?? m["teamid"])?.toString() ?? '';
            return TeamModel(label: teamLabel, teamId: teamId);
          }).toList() ??
          [],

      cupTeams:
          (json['cup_teams'] as List?)?.map((m) {
            final String series = m["series"]?.toString() ?? '';
            String leagueCode = '';
            if (series.isNotEmpty) {
              final parts = series.split(" ");
              if (parts.isNotEmpty) leagueCode = parts.last;
            }
            String teamLabel = "${m['team'] ?? ''} ($leagueCode)";
            final teamId =
                (m["id"] ?? m["team_id"] ?? m["teamid"])?.toString() ?? '';
            return TeamModel(label: teamLabel, teamId: teamId);
          }).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'club_code': code,
      'label': label,
      'club_id': clubId,
      'general': {
        'Voorzitter': chairman,
        'Secretaris': secretary,
        'Website': website,
      },
      'competition_teams': compTeams
          .map((t) => {'team': t.name, 'id': t.teamId, 'series': t.leagueName})
          .toList(),
      'cup_teams': cupTeams
          .map((t) => {'team': t.name, 'id': t.teamId, 'series': t.leagueName})
          .toList(),
    };
  }

  Future<ClubModel> load({bool forceReload = false}) async {
    final key = clubId;
    final cached = _clubCache.get(key);
    if (cached != null && !forceReload) return cached;

    final uri = Uri.parse(
      '${apiBaseUrl}api/get/club?club_label=$label&club_id=$clubId',
    );
    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        log('ClubModel', 'API error ${response.statusCode}: ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
      final data = jsonDecode(response.body);
      final club = ClubModel.fromJson(data);

      _clubCache.put(key, club);
      return club;
    } catch (e) {
      log('ClubModel', 'load failed for $clubId', error: e);
      final fallback = _clubCache.get(key);
      if (fallback != null) return fallback;
      rethrow;
    }
  }
}

class TeamModel {
  final String label;
  final String name;
  final String leagueName;
  final String teamId;
  final String leagueId;
  final List<GameModel> games;
  final List<dynamic> ranking;
  final String? rankingAlert;
  final String? calendarUrl;
  final bool isLoaded;
  bool isFavorite;

  TeamModel({
    required this.label,
    required this.teamId,
    this.name = '',
    this.leagueName = '',
    this.leagueId = '',
    this.games = const [],
    this.ranking = const [],
    this.rankingAlert,
    this.calendarUrl,
    this.isLoaded = false,
    this.isFavorite = false,
  });

  factory TeamModel.fromJson(
    Map<String, dynamic> json, {
    bool isLoaded = false,
  }) {
    final label = json['label'] ?? json['team'] ?? '';
    final match = RegExp(r'\(([^)]+)\)').firstMatch(label);
    final leagueIdRaw = match?.group(1) ?? '';
    final games =
        (json['matches'] as List?)
            ?.map((m) => GameModel.fromJson(m))
            .toList() ??
        [];

    String name = json['name']?.toString() ?? '';
    if (name.isEmpty) {
      name = label.replaceFirst(RegExp(r'\([^)]+\)'), '').trim();
    }
    if (name.isEmpty) name = label;

    List<dynamic> ranking = [];
    String? alert = json['alert'] as String?;

    final rawRanking = json['ranking'];
    if (rawRanking is List) {
      // The API normally returns a flat list of ranking rows, with any
      // alert text as a separate top-level "alert" field. Older/transitional
      // responses may still wrap it as [rows, alertOrNull] - handle both,
      // and don't require index 1 to be a String (it's usually null).
      if (rawRanking.length == 2 &&
          rawRanking[0] is List &&
          (rawRanking[1] == null || rawRanking[1] is String)) {
        ranking = rawRanking[0];
        alert ??= rawRanking[1] as String?;
      } else {
        ranking = rawRanking;
      }
    }

    return TeamModel(
      label: label,
      teamId: (json['team_id'] ?? json['id'])?.toString() ?? '',
      name: name,
      leagueName: json['league'] ?? leagueIdRaw,
      leagueId: leagueIdRaw,
      games: games,
      ranking: ranking,
      rankingAlert: alert,
      calendarUrl: json['calendar']?.toString(),
      isLoaded: isLoaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'team_id': teamId,
      'name': name,
      'league': leagueName,
      'matches': games.map((g) => g.toJson()).toList(),
      'ranking': rankingAlert != null ? [ranking, rankingAlert] : ranking,
      'calendar': calendarUrl,
    };
  }

  Future<TeamModel> load({bool forceReload = false}) async {
    final key = teamId;

    final cached = _teamCache.get(key);
    if (cached != null && !forceReload) return cached;

    final uri = Uri.parse(
      '${apiBaseUrl}api/get/team?label=${_cleanLabel()}&team_id=$teamId',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        log('TeamModel', 'API error ${response.statusCode}: ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Preserve existing info if missing in the details response
      data.putIfAbsent('team_id', () => teamId);
      data.putIfAbsent('label', () => label);

      final team = TeamModel.fromJson(data, isLoaded: true);

      _teamCache.put(key, team);
      return team;
    } catch (e) {
      log('TeamModel', 'load failed for $teamId', error: e);
      // If we have any cached data, return it as a fallback when offline
      final fallback = _teamCache.get(key);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  String _cleanLabel() {
    const ignoreList = ["(+)"];
    final trimmed = label.trim();

    if (trimmed.endsWith(')')) {
      final lastOpen = trimmed.lastIndexOf('(');
      if (lastOpen != -1) {
        final suffix = trimmed.substring(lastOpen);

        if (ignoreList.contains(suffix)) {
          return trimmed.substring(0, lastOpen).trimRight();
        }
      }
    }

    final plusIndex = trimmed.lastIndexOf('+');
    if (plusIndex != -1 && plusIndex > trimmed.length - 5) {
      final afterPlus = trimmed.substring(plusIndex);

      final isNumericSuffix = RegExp(r'^\+\d+$').hasMatch(afterPlus);

      if (isNumericSuffix) {
        return trimmed.substring(0, plusIndex).trimRight();
      }
    }

    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamModel &&
          runtimeType == other.runtimeType &&
          teamId == other.teamId;

  @override
  int get hashCode => teamId.hashCode;
}

class GameModel {
  final String matchCode;
  final String? matchId;
  final String day;
  final String date;
  final String time;
  final TeamModel homeTeam;
  final TeamModel awayTeam;
  final String venue;
  final String result;

  const GameModel({
    required this.matchCode,
    this.matchId,
    required this.day,
    required this.date,
    required this.time,
    required this.homeTeam,
    required this.awayTeam,
    required this.venue,
    required this.result,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    final String code = json["match_code"]?.toString() ?? '';
    String leagueId = '';
    if (code.contains("-")) {
      leagueId = "(${code.split("-")[0]})";
    }

    final home = json["home_team"] as Map<String, dynamic>? ?? {};
    final away = json["away_team"] as Map<String, dynamic>? ?? {};

    return GameModel(
      matchCode: code,
      matchId: json["match_id"]?.toString(),
      day: json["day"]?.toString() ?? '',
      date: json["date"]?.toString() ?? '',
      time: json["time"]?.toString() ?? '',
      homeTeam: TeamModel(
        label: leagueId.isNotEmpty
            ? "$leagueId ${home["name"] ?? ''}"
            : (home["name"] ?? ''),
        teamId: (home["team_id"] ?? home["id"])?.toString() ?? '',
        name: home["name"]?.toString() ?? '',
      ),
      awayTeam: TeamModel(
        label: leagueId.isNotEmpty
            ? "$leagueId ${away["name"] ?? ''}"
            : (away["name"] ?? ''),
        teamId: (away["team_id"] ?? away["id"])?.toString() ?? '',
        name: away["name"]?.toString() ?? '',
      ),
      venue: json["venue"]?.toString() ?? '',
      result: json["result"]?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_code': matchCode,
      'match_id': matchId,
      'day': day,
      'date': date,
      'time': time,
      'home_team': {'name': homeTeam.name, 'team_id': homeTeam.teamId},
      'away_team': {'name': awayTeam.name, 'team_id': awayTeam.teamId},
      'venue': venue,
      'result': result,
    };
  }

  /// Returns true if [teamId] won this match, false if it lost, or null if
  /// the match hasn't been played yet, the result couldn't be parsed, or
  /// [teamId] didn't play in this match.
  bool? didTeamWin(String teamId) {
    if (result.isEmpty) return null;
    if (teamId != homeTeam.teamId && teamId != awayTeam.teamId) return null;

    final parts = result.split('-').map((p) => p.trim()).toList();
    if (parts.length != 2) return null;

    final homeSets = int.tryParse(parts[0]);
    final awaySets = int.tryParse(parts[1]);
    if (homeSets == null || awaySets == null || homeSets == awaySets) {
      return null;
    }

    final homeWon = homeSets > awaySets;
    return teamId == homeTeam.teamId ? homeWon : !homeWon;
  }
}

/// Per-set scores for a single match, fetched lazily (on demand, not
/// bundled with team/club loads) via the API's /api/get/match route.
class MatchDetailModel {
  final String matchCode;
  final String? result;
  final List<({int home, int away})> sets;

  const MatchDetailModel({
    required this.matchCode,
    this.result,
    this.sets = const [],
  });

  factory MatchDetailModel.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    return MatchDetailModel(
      matchCode: json['match_code']?.toString() ?? '',
      result: json['result']?.toString(),
      sets: rawSets
          .whereType<Map<String, dynamic>>()
          .map(
            (s) => (
              home: (s['home'] as num?)?.toInt() ?? 0,
              away: (s['away'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
    );
  }

  static Future<MatchDetailModel> load(String matchCode, String matchId) async {
    final uri = Uri.parse(
      '${apiBaseUrl}api/get/match'
      '?match_code=${Uri.encodeComponent(matchCode)}&match_id=$matchId',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }

    return MatchDetailModel.fromJson(jsonDecode(response.body));
  }
}

class VLoadingPage extends StatelessWidget {
  const VLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_volleyball_rounded,
                size: 64,
                color: secondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'VolleyStats',
                style: VTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gegevens laden...',
                style: VTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: accentYellow,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
