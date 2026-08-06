import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'match_card.dart';
import 'search_item_club.dart';
import 'search_item_team.dart';
import 'favorite_team_card.dart';
import 'club_team_row.dart';
import 'team_detail_match_card.dart';
import 'ranking_row.dart';
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
import 'notification_service.dart';
import 'theme_service.dart';
import 'persistence_service.dart';

const String apiBaseUrl = "http://volleyapi.sqnder.dev/";
// const String apiBaseUrl = "http://192.168.1.43:8000/";
const String dot = "\u00B7";

// ============================================================
// CACHE
// ============================================================
final Map<String, ClubModel> _clubCache = {};
final Map<String, TeamModel> _teamCache = {};
final Map<String, LeagueModel> _leagueCache = {};

// ============================================================
// Main
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize in parallel for faster startup
  await Future.wait([
    ThemeService.init(),
    NotificationService.init(),
    _loadPersistentCaches(),
  ]);

  // Start pre-loading favorites in background
  FavoritesService.preloadFavorites();
  runApp(const VolleyStatsApp());
}

Future<void> _loadPersistentCaches() async {
  try {
    final clubsJson = await PersistenceService.loadClubs();
    clubsJson.forEach((key, value) {
      _clubCache[key] = ClubModel.fromJson(value as Map<String, dynamic>);
    });

    final teamsJson = await PersistenceService.loadTeams();
    teamsJson.forEach((key, value) {
      _teamCache[key] = TeamModel.fromJson(value as Map<String, dynamic>);
    });

    final leaguesJson = await PersistenceService.loadLeagues();
    leaguesJson.forEach((key, value) {
      _leagueCache[key] = LeagueModel.fromJson(value as Map<String, dynamic>);
    });
    debugPrint('Persistent caches loaded successfully');
  } catch (e) {
    debugPrint('Error loading persistent caches: $e');
  }
}

class VolleyStatsApp extends StatelessWidget {
  const VolleyStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          home: const MainShell(),
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

  void _loadHomeMatches() {
    setState(() {
      _homeMatchesFuture = _fetchHomeMatches();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchHomeMatches() async {
    final favorites = await FavoritesService.loadFavorites();
    if (favorites.isEmpty) return [];

    final List<Map<String, dynamic>> allMatches = [];
    final Set<String> matchCodes = {};

    for (var favTeam in favorites) {
      try {
        final fullTeam = await favTeam.load();
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
              'fav_name': fullTeam.name,
              'team_model': fullTeam,
              'date_obj': _parseDate(game.date),
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading home matches for ${favTeam.label}: $e');
      }
    }

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
    return CustomScrollView(
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
                  GestureDetector(
                    onTap: () =>
                        VToastOverlay.show(context, 'Geen nieuwe notificaties'),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 15,
                            color: secondary,
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accentRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            label: _formatDateFull(item['label']),
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

  String _formatDateFull(String dateStr) {
    final parts = dateStr.split('/');
    final dagen = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
    final maanden = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    final d = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
    return '${dagen[d.weekday - 1]} ${d.day} ${maanden[d.month - 1]}';
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
  bool _hasSearched = false;
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
    if (query.length < 2) {
      setState(() {
        _apiClubs = [];
        _apiTeams = [];
        _hasSearched = false;
        _isLoading = false;
        _isOffline = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
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
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        setState(() => _isLoading = false);
        VToastOverlay.show(
          context,
          'Fout bij het laden: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Search Error: $e');
      setState(() {
        _isLoading = false;
        if (e is SocketException) {
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
    final showResults = _hasSearched;

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
          VEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Je bent offline',
            subtitle: 'Controleer je verbinding om te kunnen zoeken.',
            actionLabel: 'Opnieuw proberen',
            onActionTap: () => _performSearch(_query),
          ),
        ] else if (_query == '') ...[
          VEmptyState(
            icon: Icons.search,
            title: 'Zoek clubs of teams',
            subtitle: 'Type iets om te beginnen (bv: Mendo)',
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
            VEmptyState(
              icon: Icons.search,
              title: 'Geen resultaten voor "$_query"',
              subtitle: 'Probeer een andere zoekterm.',
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

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    FavoritesService.favoritesNotifier.addListener(_loadFavorites);
  }

  @override
  void dispose() {
    FavoritesService.favoritesNotifier.removeListener(_loadFavorites);
    super.dispose();
  }

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = FavoritesService.loadFavorites();
    });
  }

  Map<String, dynamic>? _parseMatchDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;

      final dagen = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
      final maanden = [
        'jan',
        'feb',
        'mrt',
        'apr',
        'mei',
        'jun',
        'jul',
        'aug',
        'sep',
        'okt',
        'nov',
        'dec',
      ];

      final d = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );

      return {
        'day': dagen[d.weekday - 1],
        'dayNum': d.day,
        'month': maanden[d.month - 1],
      };
    } catch (e) {
      return null;
    }
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
          child: FutureBuilder<List<TeamModel>>(
            future: _favoritesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final favorites = snapshot.data ?? [];

              if (favorites.isEmpty) {
                return const VEmptyState(
                  icon: Icons.star_border,
                  title: 'Geen favorieten',
                  subtitle:
                      'Voeg teams toe aan je favorieten om ze hier te bekijken.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final savedTeam = favorites[index];

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
                      final hasMatch = fullTeam.games.isNotEmpty;
                      final nextMatch = hasMatch ? fullTeam.games.first : null;
                      final dateParts = nextMatch != null
                          ? _parseMatchDate(nextMatch.date)
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
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);
  int _favCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await FavoritesService.areNotificationsEnabled();
    final time = await FavoritesService.getNotificationTime();
    final favs = await FavoritesService.loadFavorites();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _notificationTime = time;
        _favCount = favs.length;
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
        const SizedBox(height: 20),

        // Profiel
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardBg, cardBgAlt],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person, size: 22, color: primary),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VolleyStats Gebruiker',
                    style: VTextStyles.bodyBold.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_favCount teams gevolgd',
                    style: VTextStyles.bodySecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
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
  late Future<ClubModel> _clubFuture;
  final Map<String, TeamModel> _loadedTeams = {};

  @override
  void initState() {
    super.initState();
    _clubFuture = widget.club.load();
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
              debugPrint("CLUB FUTURE ERROR: ${snapshot.error}");
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
      ),

      body: FutureBuilder<ClubModel>(
        future: _clubFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            bool isOffline = false;
            if (error is SocketException ||
                error.toString().contains('Failed host lookup')) {
              isOffline = true;
            }

            return Center(
              child: VEmptyState(
                icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
                title: isOffline ? 'Je bent offline' : 'Fout bij laden',
                subtitle: isOffline
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
                          loaded.isFavorite = await FavoritesService.isFavorite(
                            loaded.teamId,
                          );
                          _loadedTeams[loaded.teamId] = loaded;
                          return loaded;
                        }),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint(
                        'Error loading team ${team.teamId}: ${snapshot.error}',
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

                    if (loadedTeam.games.isNotEmpty) {
                      GameModel nextMatch = loadedTeam.games.first;
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

                    // Removed debug prints

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VClubTeamRow(
                        teamName: loadedTeam.name,
                        seriesLabel: loadedTeam.leagueName,
                        nextMatch: nextMatchString,
                        venue: venue,
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
                              await FavoritesService.toggleFavorite(loadedTeam);
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
      debugPrint('Error syncing calendar: $e');
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
      body: FutureBuilder<TeamModel>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: VEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Wedstrijden laden',
                subtitle: 'Even geduld, we halen de wedstrijden op...',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.games.isEmpty) {
            return Center(
              child: VEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Geen wedstrijden beschikbaar',
                subtitle: 'De wedstrijdata worden binnenkort bekendgemaakt.',
              ),
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

            final day = int.parse(parts[0]);
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
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
                          isHomeTeam: m.homeTeam.name.contains(
                            team.name.split(' ').last,
                          ),
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

  Future<ClubModel> load() async {
    final key = clubId;
    if (_clubCache.containsKey(key)) {
      return _clubCache[key]!;
    }

    final uri = Uri.parse(
      '${apiBaseUrl}api/get/club?club_label=$label&club_id=$clubId',
    );
    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
      final data = jsonDecode(response.body);
      final club = ClubModel.fromJson(data);

      _clubCache[key] = club;

      // Cache management: Keep only last 50 entries
      if (_clubCache.length > 50) {
        _clubCache.remove(_clubCache.keys.first);
      }

      // Throttled persist
      _persistClubsThrottled();
      return club;
    } catch (e) {
      debugPrint('ClubModel.load failed for $clubId: $e');
      if (_clubCache.containsKey(key)) {
        return _clubCache[key]!;
      }
      rethrow;
    }
  }
}

Timer? _clubsPersistTimer;
void _persistClubsThrottled() {
  _clubsPersistTimer?.cancel();
  _clubsPersistTimer = Timer(const Duration(seconds: 2), () async {
    final Map<String, dynamic> jsonMap = {};
    _clubCache.forEach((key, value) {
      jsonMap[key] = value.toJson();
    });
    await PersistenceService.saveClubs(jsonMap);
    debugPrint('Clubs persisted to disk');
  });
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
    String? alert;

    final rawRanking = json['ranking'];
    if (rawRanking is List) {
      if (rawRanking.length == 2 &&
          rawRanking[0] is List &&
          rawRanking[1] is String) {
        ranking = rawRanking[0];
        alert = rawRanking[1];
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

    if (_teamCache.containsKey(key) && !forceReload) {
      return _teamCache[key]!;
    }

    final uri = Uri.parse(
      '${apiBaseUrl}api/get/team?label=${_cleanLabel()}&team_id=$teamId',
    );
    debugPrint('TeamModel.load URI: $uri');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Preserve existing info if missing in the details response
      data.putIfAbsent('team_id', () => teamId);
      data.putIfAbsent('label', () => label);

      final team = TeamModel.fromJson(data, isLoaded: true);

      _teamCache[key] = team;

      // Cache management: Keep only last 100 teams
      if (_teamCache.length > 100) {
        _teamCache.remove(_teamCache.keys.first);
      }

      // Throttled persist
      _persistTeamsThrottled();

      return team;
    } catch (e) {
      debugPrint('TeamModel.load failed for $teamId: $e');
      // If we have any cached data, return it as a fallback when offline
      if (_teamCache.containsKey(key)) {
        return _teamCache[key]!;
      }
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

Timer? _teamsPersistTimer;
void _persistTeamsThrottled() {
  _teamsPersistTimer?.cancel();
  _teamsPersistTimer = Timer(const Duration(seconds: 3), () async {
    final Map<String, dynamic> jsonMap = {};
    _teamCache.forEach((key, value) {
      jsonMap[key] = value.toJson();
    });
    await PersistenceService.saveTeams(jsonMap);
    debugPrint('Teams persisted to disk');
  });
}

class GameModel {
  final String matchCode;
  final String day;
  final String date;
  final String time;
  final TeamModel homeTeam;
  final TeamModel awayTeam;
  final String venue;
  final String result;

  const GameModel({
    required this.matchCode,
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
      'day': day,
      'date': date,
      'time': time,
      'home_team': {'name': homeTeam.name, 'team_id': homeTeam.teamId},
      'away_team': {'name': awayTeam.name, 'team_id': awayTeam.teamId},
      'venue': venue,
      'result': result,
    };
  }
}

class LeagueModel {
  final String series;
  final String seriesId;
  final List<dynamic> ranking;
  final String? alert;

  LeagueModel({
    required this.series,
    required this.seriesId,
    required this.ranking,
    this.alert,
  });

  factory LeagueModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> ranking = [];
    String? alert = json['alert'] as String?;

    final rawRanking = json['ranking'];
    if (rawRanking is List) {
      if (rawRanking.length == 2 &&
          rawRanking[0] is List &&
          rawRanking[1] is String) {
        ranking = rawRanking[0];
        alert ??= rawRanking[1];
      } else {
        ranking = rawRanking;
      }
    }

    return LeagueModel(
      series: json['series'] ?? '',
      seriesId: json['series_id']?.toString() ?? '',
      ranking: ranking,
      alert: alert,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series,
      'series_id': seriesId,
      'ranking': alert != null ? [ranking, alert] : ranking,
      'alert': alert,
    };
  }

  static Future<LeagueModel> load(
    String label, {
    bool forceReload = false,
  }) async {
    final key = label;

    if (_leagueCache.containsKey(key) && !forceReload) {
      return _leagueCache[key]!;
    }

    final encodedLabel = Uri.encodeComponent(label);
    final url = '${apiBaseUrl}api/get/league?label=$encodedLabel&season=2026';
    final uri = Uri.parse(url);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final league = LeagueModel.fromJson(data);

      _leagueCache[key] = league;
      // Throttled persist
      _persistLeaguesThrottled();
      return league;
    } catch (e) {
      debugPrint('LeagueModel.load failed for $label: $e');
      if (_leagueCache.containsKey(key)) {
        return _leagueCache[key]!;
      }
      rethrow;
    }
  }
}

Timer? _leaguesPersistTimer;
void _persistLeaguesThrottled() {
  _leaguesPersistTimer?.cancel();
  _leaguesPersistTimer = Timer(const Duration(seconds: 5), () async {
    final Map<String, dynamic> jsonMap = {};
    _leagueCache.forEach((key, value) {
      jsonMap[key] = value.toJson();
    });
    await PersistenceService.saveLeagues(jsonMap);
    debugPrint('Leagues persisted to disk');
  });
}
