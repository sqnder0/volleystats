import 'package:flutter/material.dart';
import 'colors.dart';
import 'league_badge.dart';
import 'text_styles.dart';
import 'match_card.dart';
import 'stat_card.dart';
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
import 'dart:convert';

void main() {
  runApp(const VolleyStatsApp());
}

class VolleyStatsApp extends StatelessWidget {
  const VolleyStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VolleyStats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: primary, fontFamily: 'DM Sans'),
      home: const MainShell(),
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

  final List<Widget> _pages = const [
    HomePage(),
    SearchPage(),
    RankingsPage(),
    FavoritesPage(),
    MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: const BoxDecoration(color: primary),
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

  List<Map<String, dynamic>> get _filteredMatches {
    if (_filter == 'week') return StaticData.homeMatches.take(4).toList();
    if (_filter == 'month') return StaticData.homeMatches.take(8).toList();
    return StaticData.homeMatches;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMatches;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
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
                    const Icon(
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
                        decoration: const BoxDecoration(
                          color: accentRed,
                          shape: BoxShape.circle,
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

        // Match lijst
        ..._buildMatchList(filtered),
      ],
    );
  }

  List<Widget> _buildMatchList(List<Map<String, dynamic>> matches) {
    final List<Widget> widgets = [];
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var m in matches) {
      final dateKey = m['time'];
      grouped.putIfAbsent(dateKey, () => []).add(m);
    }

    for (var entry in grouped.entries) {
      final dateLabel = _formatDateFull(entry.key);
      widgets.add(
        VDateDivider(
          label: dateLabel,
          countLabel: '${entry.value.length} wed.',
        ),
      );
      for (var m in entry.value) {
        widgets.add(
          VMatchCard(
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
                  teamName: m['fav_name'],
                  leagueName: m['league_name'],
                ),
              ),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
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
  List<ClubModel> _apiClubs = [];
  List<SearchTeamModel> _apiTeams = [];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
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
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final uri = Uri.parse(
        'https://volleyapi.sqnder.dev/api/search?q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          final clubsJson = data['clubs'] as List<dynamic>?;
          final teamsJson = data['teams'] as List<dynamic>?;

          _apiClubs =
              clubsJson
                  ?.map((c) => ClubModel.fromJson(c as Map<String, dynamic>))
                  .toList() ??
              [];
          _apiTeams =
              teamsJson
                  ?.map(
                    (t) => SearchTeamModel.fromJson(t as Map<String, dynamic>),
                  )
                  .toList() ??
              [];
          _isLoading = false;
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
      setState(() => _isLoading = false);
      VToastOverlay.show(context, 'Kon geen verbinding maken');
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
            prefixIcon: const Icon(Icons.search, size: 14, color: secondary),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: _clearSearch,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(Icons.close, size: 16, color: secondary),
                    ),
                  )
                : null,
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: cardBorder),
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

        if (!showResults) ...[
          Text('POPULAIRE CLUBS', style: VTextStyles.smallLabel),
          const SizedBox(height: 10),
          ...StaticData.clubs
              .take(5)
              .map(
                (c) => VSearchItemClub(
                  name: c.name,
                  clubCode: c.code,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ClubDetailPage(club: c)),
                  ),
                ),
              ),
        ] else if (_isLoading) ...[
          const SizedBox(height: 60),
          const Center(child: CircularProgressIndicator(color: accentYellow)),
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
                    builder: (_) => TeamDetailPage(
                      teamName: t.name,
                      leagueName: t.leagueName,
                    ),
                  ),
                ),
                onFavoriteTap: () => VToastOverlay.show(
                  context,
                  t.isFavorite
                      ? 'Verwijderd uit favorieten'
                      : 'Toegevoegd aan favorieten',
                ),
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
  String _selectedLeague = 'VHP1';

  @override
  Widget build(BuildContext context) {
    final ranking = StaticData.rankings[_selectedLeague] ?? [];
    final favNames = ['Rotselaar A', 'Mendo Booischot B', 'Mendo Booischot A'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text('Ranking', style: VTextStyles.h2),
        const SizedBox(height: 2),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedLeague,
          dropdownColor: cardBg,
          style: VTextStyles.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: cardBorder),
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
          items: StaticData.leagueOptions
              .map(
                (l) => DropdownMenuItem<String>(
                  value: l['id'] as String,
                  child: Text(l['name'] as String, style: VTextStyles.body),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedLeague = v!),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Column(
            children: [
              const VRankingRow(
                position: 0,
                teamName: '',
                wins: 0,
                losses: 0,
                setsWon: 0,
                setsLost: 0,
                points: 0,
                isHeader: true,
              ),
              ...ranking.map(
                (r) => VRankingRow(
                  position: r['pos'],
                  teamName: r['name'],
                  wins: r['w'],
                  losses: r['l'],
                  setsWon: r['sw'],
                  setsLost: r['sl'],
                  points: r['pts'],
                  isFavorite: favNames.any((fn) => r['name'].contains(fn)),
                ),
              ),
            ],
          ),
        ),
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
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text('Favorieten', style: VTextStyles.h2),
        const SizedBox(height: 2),
        Text('Jouw gevolgde teams', style: VTextStyles.caption),
        const SizedBox(height: 20),
        ...StaticData.favoriteTeams.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VFavoriteTeamCard(
              teamName: f.name,
              leagueName: f.leagueName,
              clubName: f.club,
              nextHomeTeam: f.nextHome,
              nextAwayTeam: f.nextAway,
              nextDateDay: f.nextDay,
              nextDateDayNum: f.nextDayNum,
              nextDateMonth: f.nextMonth,
              nextTime: f.nextTime,
              hasUpcomingMatch: f.nextHome != null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamDetailPage(
                    teamName: f.name,
                    leagueName: f.leagueName,
                  ),
                ),
              ),
              onRemoveTap: () =>
                  VToastOverlay.show(context, 'Verwijderd uit favorieten'),
            ),
          ),
        ),
      ],
    );
  }
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

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
            gradient: const LinearGradient(
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
                child: const Icon(Icons.person, size: 22, color: primary),
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
                  Text('3 teams gevolgd', style: VTextStyles.bodySecondary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Instellingen
        VSettingsRow(
          icon: Icons.star,
          iconBgColor: accentYellow.withValues(alpha: 0.12),
          iconColor: accentYellow,
          title: 'Mijn Favorieten',
          subtitle: 'Beheer gevolgde teams',
        ),
        VSettingsRow(
          icon: Icons.notifications_outlined,
          iconBgColor: accentRed.withValues(alpha: 0.12),
          iconColor: accentRed,
          title: 'Notificaties',
          subtitle: 'Wedstrijdherinneringen',
          trailing: const VToggleSwitch(isOn: true),
          onTap: () =>
              VToastOverlay.show(context, 'Notificaties zijn ingeschakeld'),
        ),
        VSettingsRow(
          icon: Icons.dark_mode_outlined,
          iconBgColor: const Color(0xFF3498DB).withValues(alpha: 0.12),
          iconColor: const Color(0xFF3498DB),
          title: 'Donkere Modus',
          subtitle: 'Altijd aan',
          trailing: const VToggleSwitch(isOn: true),
          onTap: () => VToastOverlay.show(
            context,
            'Donkere modus is standaard ingeschakeld',
          ),
        ),
        VSettingsRow(
          icon: Icons.language,
          iconBgColor: const Color(0xFF9B59B6).withValues(alpha: 0.12),
          iconColor: const Color(0xFF9B59B6),
          title: 'Taal',
          subtitle: 'Nederlands',
          onTap: () => VToastOverlay.show(context, 'Taal: Nederlands'),
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
              Text('All Belgian Volleyball Stats', style: VTextStyles.caption),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () =>
                    VToastOverlay.show(context, 'Opent volleyscores.be'),
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
                'Versie 1.0.0 · Koninklijk Belgisch Volleybalverbond',
                style: VTextStyles.dateSmall,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon(Icons.camera_alt_outlined, 'Instagram'),
                  const SizedBox(width: 16),
                  _socialIcon(Icons.language, 'X/Twitter'),
                  const SizedBox(width: 16),
                  _socialIcon(Icons.facebook, 'Facebook'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _socialIcon(IconData icon, String name) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () => VToastOverlay.show(context, 'Volg ons op $name'),
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

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final compTeams = StaticData.clubCompTeams[club.name] ?? [];
    final cupTeams = StaticData.clubCupTeams[club.name] ?? [];
    final teamsToShow = _isCompetitionTab ? compTeams : cupTeams;

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
            child: const Icon(Icons.chevron_left, color: light, size: 16),
          ),
        ),
        title: Text(
          club.name,
          style: VTextStyles.h3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Info grid
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

          // Toggle
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

          // Teams lijst
          ...teamsToShow.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VClubTeamRow(
                teamName: t['team'],
                seriesLabel: t['series'],
                ranking: t['ranking'],
                nextMatch: t['next_match'],
                isFavorite: t['is_fav'] == true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamDetailPage(
                      teamName: t['team'],
                      leagueName: t['series'],
                    ),
                  ),
                ),
                onFavoriteTap: () => VToastOverlay.show(
                  context,
                  t['is_fav'] == true ? 'Verwijderd' : 'Toegevoegd',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeamDetailPage extends StatelessWidget {
  final String teamName;
  final String leagueName;
  const TeamDetailPage({
    super.key,
    required this.teamName,
    required this.leagueName,
  });

  @override
  Widget build(BuildContext context) {
    final matches = StaticData.teamMatches[teamName] ?? [];
    Map<String, Map<String, dynamic>> grouped = {};
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

    for (var m in matches) {
      final parts = m['time'].split('/');
      final key = '${parts[1]}/${parts[2]}';
      final label = '${maanden[int.parse(parts[1]) - 1]} ${parts[2]}';
      grouped.putIfAbsent(
        key,
        () => {'label': label, 'matches': <Map<String, dynamic>>[]},
      );
      (grouped[key]!['matches'] as List<Map<String, dynamic>>).add(m);
    }

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
            child: const Icon(Icons.chevron_left, color: light, size: 16),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamName,
              style: VTextStyles.h3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            VLeagueBadge(label: leagueName),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => VToastOverlay.show(context, 'Favoriet aangepast'),
              child: const Icon(Icons.star, size: 18, color: accentYellow),
            ),
          ),
        ],
      ),
      body: matches.isEmpty
          ? VEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Geen wedstrijden beschikbaar',
              subtitle: 'De wedstrijdata worden binnenkort bekendgemaakt.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: grouped.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return const SizedBox.shrink();
                final entry = grouped.entries.elementAt(index - 1);
                final monthData = entry.value;

                final dagen = ['Zo', 'Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za'];
                final matchesList =
                    monthData['matches'] as List<Map<String, dynamic>>;
                final mParts = matchesList.first['time'].split('/');
                final d = DateTime(
                  int.parse(mParts[2]),
                  int.parse(mParts[1]),
                  int.parse(mParts[0]),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VDateDivider(label: monthData['label'] as String),
                    ...matchesList.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: VTeamDetailMatchCard(
                          homeTeam: m['home_team'] as String,
                          awayTeam: m['away_team'] as String,
                          result: m['result'] as String?,
                          venue: m['venue'] as String,
                          dateDay: dagen[d.weekday - 1],
                          dateNum: d.day,
                          dateMonth: maanden[d.month - 1].substring(0, 3),
                          timeString: m['match_time'] as String,
                          isHomeTeam: (m['home_team'] as String).contains(
                            teamName.split(' ').last,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
  final String chairman;
  final String secretary;
  final String website;
  final String clubId;

  const ClubModel({
    required this.name,
    required this.code,
    required this.chairman,
    required this.secretary,
    required this.website,
    this.clubId = '',
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      name: json['name'] ?? '',
      code: json['club_code'] ?? '',
      clubId: json['club_id']?.toString() ?? '',
      chairman: '',
      secretary: '',
      website: '',
    );
  }
}

class SearchTeamModel {
  final String name;
  final String leagueName;
  final String teamId;
  final String leagueId;
  final bool isFavorite;

  const SearchTeamModel({
    required this.name,
    required this.leagueName,
    this.teamId = '',
    this.leagueId = '',
    this.isFavorite = false,
  });

  factory SearchTeamModel.fromJson(Map<String, dynamic> json) {
    final label = json['label'] ?? '';
    final match = RegExp(r'\(([^)]+)\)').firstMatch(label);
    final leagueIdRaw = match?.group(1) ?? '';

    return SearchTeamModel(
      name: json['name'] ?? '',
      leagueName: leagueIdRaw,
      teamId: json['team_id']?.toString() ?? '',
      leagueId: leagueIdRaw,
    );
  }
}

class FavoriteTeamModel {
  final String name;
  final String leagueName;
  final String? club;
  final String? nextHome;
  final String? nextAway;
  final String? nextDay;
  final int? nextDayNum;
  final String? nextMonth;
  final String? nextTime;
  const FavoriteTeamModel({
    required this.name,
    required this.leagueName,
    this.club,
    this.nextHome,
    this.nextAway,
    this.nextDay,
    this.nextDayNum,
    this.nextMonth,
    this.nextTime,
  });
}

class StaticData {
  static final List<ClubModel> clubs = const [
    ClubModel(
      name: 'Kreg Rotselaar',
      code: 'VB-1849',
      chairman: 'Tom Van der Auwera',
      secretary: 'Liesbeth Peeters',
      website: 'kregrotselaar.be',
    ),
    ClubModel(
      name: 'Mendo Booischot',
      code: 'AH-1260',
      chairman: 'Jelle Verelst',
      secretary: 'Joris De Smet',
      website: 'mendo.be',
    ),
    ClubModel(
      name: 'VC Lennik',
      code: 'VB-0234',
      chairman: 'Jan De Smedt',
      secretary: 'An Vanhaecke',
      website: 'vclennik.be',
    ),
    ClubModel(
      name: 'Volley Haasrode',
      code: 'VB-0891',
      chairman: 'Pieter Janssens',
      secretary: 'Lien Maes',
      website: 'volleyhaasrode.be',
    ),
    ClubModel(
      name: 'VBT Machelen',
      code: 'VB-0567',
      chairman: 'Mark De Clercq',
      secretary: 'Sarah Goossens',
      website: 'vbtmachelen.be',
    ),
  ];

  static final List<SearchTeamModel> searchTeams = const [
    SearchTeamModel(
      name: 'Rotselaar A',
      leagueName: 'Heren Promo 1',
      isFavorite: true,
    ),
    SearchTeamModel(name: 'Rotselaar B', leagueName: 'Heren Promo 3B'),
    SearchTeamModel(name: 'Rotselaar A', leagueName: 'Dames Promo 1'),
    SearchTeamModel(name: 'Mendo Booischot A', leagueName: 'Nationale 1 Heren'),
    SearchTeamModel(
      name: 'Mendo Booischot B',
      leagueName: 'Nationale 2 Heren B',
      isFavorite: true,
    ),
    SearchTeamModel(
      name: 'Mendo Booischot C',
      leagueName: 'Nationale 3 Heren B',
    ),
    SearchTeamModel(
      name: 'Mendo Booischot A',
      leagueName: 'Nationale 2 Dames B',
      isFavorite: true,
    ),
    SearchTeamModel(name: 'Mendo Booischot D', leagueName: 'Heren Promo 2'),
  ];

  static final List<FavoriteTeamModel> favoriteTeams = const [
    FavoriteTeamModel(
      name: 'Kreg Rotselaar A',
      leagueName: 'Heren Promo 1',
      club: 'Kreg Rotselaar',
      nextHome: 'Kreg Rotselaar A',
      nextAway: 'VC Lennik A',
      nextDay: 'Zo',
      nextDayNum: 13,
      nextMonth: 'sep',
      nextTime: '16:00',
    ),
    FavoriteTeamModel(
      name: 'Mendo Booischot B',
      leagueName: 'Nationale 2 Heren B',
      club: 'Mendo Booischot',
      nextHome: 'Mavo Dilsen-Stokkem A',
      nextAway: 'Mendo Booischot B',
      nextDay: 'Za',
      nextDayNum: 12,
      nextMonth: 'sep',
      nextTime: '20:00',
    ),
    FavoriteTeamModel(
      name: 'Mendo Booischot A',
      leagueName: 'Nationale 2 Dames B',
      club: 'Mendo Booischot',
      nextHome: 'Noust Spinley Dessel A',
      nextAway: 'Mendo Booischot A',
      nextDay: 'Za',
      nextDayNum: 12,
      nextMonth: 'sep',
      nextTime: '18:00',
    ),
  ];

  static final List<Map<String, dynamic>> homeMatches = [
    {
      'home_team': 'Kreg Rotselaar A',
      'away_team': 'VC Lennik A',
      'result': null,
      'venue': 'Rotselaar, Sportoase De Meander',
      'league_name': 'Heren Promo 1',
      'time': '13/09/2026',
      'match_time': '16:00',
      'is_fav_home': true,
      'fav_name': 'Kreg Rotselaar A',
    },
    {
      'home_team': 'Mavo Dilsen-Stokkem A',
      'away_team': 'Mendo Booischot B',
      'result': null,
      'venue': 'Dilsen-Stokkem, Sporthal',
      'league_name': 'Nationale 2 Heren B',
      'time': '13/09/2026',
      'match_time': '20:00',
      'is_fav_home': false,
      'fav_name': 'Mendo Booischot B',
    },
    {
      'home_team': 'Noust Spinley Dessel A',
      'away_team': 'Mendo Booischot A',
      'result': null,
      'venue': 'Dessel, Sporthal',
      'league_name': 'Nationale 2 Dames B',
      'time': '13/09/2026',
      'match_time': '18:00',
      'is_fav_home': false,
      'fav_name': 'Mendo Booischot A',
    },
    {
      'home_team': 'Kruikenburg Ternat B',
      'away_team': 'Kreg Rotselaar A',
      'result': null,
      'venue': 'Ternat, Sporthal Kruikenburg',
      'league_name': 'Heren Promo 1',
      'time': '19/09/2026',
      'match_time': '20:30',
      'is_fav_home': false,
      'fav_name': 'Kreg Rotselaar A',
    },
    {
      'home_team': 'Mendo Booischot B',
      'away_team': 'VC Achel A',
      'result': null,
      'venue': 'Booischot, Sporthal Mendo',
      'league_name': 'Nationale 2 Heren B',
      'time': '20/09/2026',
      'match_time': '20:00',
      'is_fav_home': true,
      'fav_name': 'Mendo Booischot B',
    },
    {
      'home_team': 'Kreg Rotselaar A',
      'away_team': 'VBT Machelen B',
      'result': null,
      'venue': 'Rotselaar, Sportoase De Meander',
      'league_name': 'Heren Promo 1',
      'time': '27/09/2026',
      'match_time': '16:00',
      'is_fav_home': true,
      'fav_name': 'Kreg Rotselaar A',
    },
    {
      'home_team': 'Kreg Rotselaar A',
      'away_team': 'VC Feniks Haacht B',
      'result': '3-1',
      'venue': 'Rotselaar, Sportoase De Meander',
      'league_name': 'Heren Promo 1',
      'time': '15/11/2026',
      'match_time': '16:00',
      'is_fav_home': true,
      'fav_name': 'Kreg Rotselaar A',
    },
    {
      'home_team': 'Mendo Booischot B',
      'away_team': 'Vlimmeren Sport A',
      'result': null,
      'venue': 'Booischot, Sporthal Mendo',
      'league_name': 'Nationale 2 Heren B',
      'time': '18/10/2026',
      'match_time': '20:00',
      'is_fav_home': true,
      'fav_name': 'Mendo Booischot B',
    },
    {
      'home_team': 'Kreg Rotselaar A',
      'away_team': 'Wolvertem Sporting A',
      'result': null,
      'venue': 'Rotselaar, Sportoase De Meander',
      'league_name': 'Heren Promo 1',
      'time': '11/10/2026',
      'match_time': '16:00',
      'is_fav_home': true,
      'fav_name': 'Kreg Rotselaar A',
    },
    {
      'home_team': 'Mendo Booischot A',
      'away_team': 'VC Beveren A',
      'result': null,
      'venue': 'Booischot, Sporthal Mendo',
      'league_name': 'Nationale 2 Dames B',
      'time': '27/09/2026',
      'match_time': '20:00',
      'is_fav_home': true,
      'fav_name': 'Mendo Booischot A',
    },
    {
      'home_team': 'Davoc Lot',
      'away_team': 'Kreg Rotselaar A',
      'result': null,
      'venue': 'Lot, Vogelenzang',
      'league_name': 'Heren Promo 1',
      'time': '23/10/2026',
      'match_time': '21:00',
      'is_fav_home': false,
      'fav_name': 'Kreg Rotselaar A',
    },
    {
      'home_team': 'Kreg Rotselaar A',
      'away_team': 'Lizards Lubbeek-Leuven B',
      'result': null,
      'venue': 'Rotselaar, Sportoase De Meander',
      'league_name': 'Heren Promo 1',
      'time': '06/12/2026',
      'match_time': '16:00',
      'is_fav_home': true,
      'fav_name': 'Kreg Rotselaar A',
    },
  ];

  static final List<Map<String, dynamic>> leagueOptions = const [
    {'id': 'VHP1', 'name': 'Heren Promo 1'},
    {'id': 'NAT2H-B', 'name': 'Nationale 2 Heren B'},
    {'id': 'NAT2D-B', 'name': 'Nationale 2 Dames B'},
    {'id': 'NAT1H', 'name': 'Nationale 1 Heren'},
  ];

  static final Map<String, List<Map<String, dynamic>>> rankings = {
    'VHP1': [
      {
        'pos': 1,
        'name': 'Volley Haasrode Leuven D',
        'w': 7,
        'l': 1,
        'sw': 22,
        'sl': 6,
        'pts': 21,
      },
      {
        'pos': 2,
        'name': 'VC Lennik A',
        'w': 6,
        'l': 2,
        'sw': 20,
        'sl': 8,
        'pts': 18,
      },
      {
        'pos': 3,
        'name': 'Kruikenburg Ternat B',
        'w': 6,
        'l': 2,
        'sw': 19,
        'sl': 9,
        'pts': 17,
      },
      {
        'pos': 4,
        'name': 'Zuun Volleybal Club A',
        'w': 5,
        'l': 3,
        'sw': 17,
        'sl': 11,
        'pts': 15,
      },
      {
        'pos': 5,
        'name': 'Kreg Rotselaar A',
        'w': 4,
        'l': 4,
        'sw': 16,
        'sl': 14,
        'pts': 13,
      },
      {
        'pos': 6,
        'name': 'Wolvertem Sporting A',
        'w': 4,
        'l': 4,
        'sw': 14,
        'sl': 15,
        'pts': 12,
      },
      {
        'pos': 7,
        'name': 'Volley Opwijk',
        'w': 3,
        'l': 5,
        'sw': 13,
        'sl': 16,
        'pts': 10,
      },
      {
        'pos': 8,
        'name': 'Davoc Lot',
        'w': 3,
        'l': 5,
        'sw': 12,
        'sl': 17,
        'pts': 9,
      },
      {
        'pos': 9,
        'name': 'VC Feniks Haacht B',
        'w': 2,
        'l': 6,
        'sw': 10,
        'sl': 19,
        'pts': 7,
      },
      {
        'pos': 10,
        'name': 'VBT Machelen B',
        'w': 2,
        'l': 6,
        'sw': 9,
        'sl': 20,
        'pts': 6,
      },
      {
        'pos': 11,
        'name': 'Volley Eternit Kapelle-Op-Den-Bos B',
        'w': 1,
        'l': 7,
        'sw': 7,
        'sl': 21,
        'pts': 4,
      },
      {
        'pos': 12,
        'name': 'Lizards Lubbeek-Leuven B',
        'w': 0,
        'l': 8,
        'sw': 5,
        'sl': 24,
        'pts': 1,
      },
    ],
    'NAT2H-B': [
      {
        'pos': 1,
        'name': 'Mavo Dilsen-Stokkem A',
        'w': 6,
        'l': 0,
        'sw': 18,
        'sl': 3,
        'pts': 18,
      },
      {
        'pos': 2,
        'name': 'VOC Herentals A',
        'w': 5,
        'l': 1,
        'sw': 16,
        'sl': 5,
        'pts': 15,
      },
      {
        'pos': 3,
        'name': 'Vlimmeren Sport A',
        'w': 4,
        'l': 2,
        'sw': 14,
        'sl': 8,
        'pts': 13,
      },
      {
        'pos': 4,
        'name': 'Mendo Booischot B',
        'w': 3,
        'l': 3,
        'sw': 13,
        'sl': 10,
        'pts': 10,
      },
      {
        'pos': 5,
        'name': 'VC Maasmechelen A',
        'w': 3,
        'l': 3,
        'sw': 12,
        'sl': 11,
        'pts': 9,
      },
      {
        'pos': 6,
        'name': 'Turnhout A',
        'w': 2,
        'l': 4,
        'sw': 10,
        'sl': 13,
        'pts': 7,
      },
      {
        'pos': 7,
        'name': 'VC Achel A',
        'w': 1,
        'l': 5,
        'sw': 7,
        'sl': 15,
        'pts': 4,
      },
      {
        'pos': 8,
        'name': 'VC Bree A',
        'w': 1,
        'l': 5,
        'sw': 6,
        'sl': 16,
        'pts': 3,
      },
      {
        'pos': 9,
        'name': 'VCK Beringen A',
        'w': 0,
        'l': 6,
        'sw': 4,
        'sl': 18,
        'pts': 1,
      },
    ],
    'NAT2D-B': [
      {
        'pos': 1,
        'name': 'Noust Spinley Dessel A',
        'w': 5,
        'l': 0,
        'sw': 15,
        'sl': 2,
        'pts': 15,
      },
      {
        'pos': 2,
        'name': 'Mendo Booischot A',
        'w': 4,
        'l': 1,
        'sw': 13,
        'sl': 5,
        'pts': 12,
      },
      {
        'pos': 3,
        'name': 'VOS Tessenderlo A',
        'w': 3,
        'l': 2,
        'sw': 11,
        'sl': 7,
        'pts': 10,
      },
      {
        'pos': 4,
        'name': 'Dynamo Heusden-Zolder A',
        'w': 3,
        'l': 2,
        'sw': 10,
        'sl': 8,
        'pts': 9,
      },
      {
        'pos': 5,
        'name': 'VCB Dilsen A',
        'w': 2,
        'l': 3,
        'sw': 8,
        'sl': 10,
        'pts': 7,
      },
      {
        'pos': 6,
        'name': 'VC Beveren A',
        'w': 1,
        'l': 4,
        'sw': 6,
        'sl': 13,
        'pts': 4,
      },
      {
        'pos': 7,
        'name': 'Voc Schriek A',
        'w': 1,
        'l': 4,
        'sw': 5,
        'sl': 14,
        'pts': 3,
      },
      {
        'pos': 8,
        'name': 'V O L A K Vorselaar A',
        'w': 0,
        'l': 5,
        'sw': 3,
        'sl': 15,
        'pts': 1,
      },
    ],
    'NAT1H': [
      {
        'pos': 1,
        'name': 'VC Packo Zedelgem A',
        'w': 7,
        'l': 0,
        'sw': 21,
        'sl': 3,
        'pts': 21,
      },
      {
        'pos': 2,
        'name': 'Voc Hamme A',
        'w': 6,
        'l': 1,
        'sw': 19,
        'sl': 6,
        'pts': 18,
      },
      {
        'pos': 3,
        'name': 'VKJ De Haan A',
        'w': 5,
        'l': 2,
        'sw': 17,
        'sl': 8,
        'pts': 15,
      },
      {
        'pos': 4,
        'name': 'VC Halen A',
        'w': 4,
        'l': 3,
        'sw': 15,
        'sl': 10,
        'pts': 12,
      },
      {
        'pos': 5,
        'name': 'Mendo Booischot A',
        'w': 3,
        'l': 4,
        'sw': 13,
        'sl': 13,
        'pts': 10,
      },
      {
        'pos': 6,
        'name': 'VTB Ieper A',
        'w': 2,
        'l': 5,
        'sw': 10,
        'sl': 15,
        'pts': 7,
      },
      {
        'pos': 7,
        'name': 'VOC Keerbergen A',
        'w': 1,
        'l': 6,
        'sw': 8,
        'sl': 18,
        'pts': 4,
      },
      {
        'pos': 8,
        'name': 'VCM Brugge A',
        'w': 0,
        'l': 7,
        'sw': 5,
        'sl': 21,
        'pts': 1,
      },
    ],
  };

  static final Map<String, List<Map<String, dynamic>>> clubCompTeams = {
    'Kreg Rotselaar': [
      {
        'team': 'Kreg Rotselaar A',
        'series': 'Heren Promo 1',
        'ranking': '5e',
        'next_match': '13/09/2026 16:00 Kreg Rotselaar A - VC Lennik A',
        'is_fav': true,
      },
      {
        'team': 'Kreg Rotselaar B',
        'series': 'Heren Promo 3 B',
        'ranking': '8e',
        'next_match': '13/09/2026 14:00 Kreg Rotselaar B - VBT Machelen C',
        'is_fav': false,
      },
      {
        'team': 'Kreg Rotselaar A',
        'series': 'Dames Promo 1',
        'ranking': '3e',
        'next_match': '12/09/2026 18:00 VC Lennik D - Kreg Rotselaar A',
        'is_fav': false,
      },
      {
        'team': 'Kreg Rotselaar',
        'series': 'Dames Promo 3 C',
        'ranking': '6e',
        'next_match': '13/09/2026 15:00 Kreg Rotselaar - Voc Schriek D',
        'is_fav': false,
      },
      {
        'team': 'Kreg Rotselaar',
        'series': 'Dames Promo 4 A',
        'ranking': '4e',
        'next_match':
            '12/09/2026 17:00 Grinta Valentino Lint C - Kreg Rotselaar',
        'is_fav': false,
      },
    ],
    'Mendo Booischot': [
      {
        'team': 'Mendo Booischot A',
        'series': 'Nationale 1 Heren',
        'ranking': '7e',
        'next_match':
            '12/09/2026 20:00 VC Packo Zedelgem A - Mendo Booischot A',
        'is_fav': false,
      },
      {
        'team': 'Mendo Booischot B',
        'series': 'Nationale 2 Heren B',
        'ranking': '4e',
        'next_match':
            '12/09/2026 20:00 Mavo Dilsen-Stokkem A - Mendo Booischot B',
        'is_fav': true,
      },
      {
        'team': 'Mendo Booischot C',
        'series': 'Nationale 3 Heren B',
        'ranking': '9e',
        'next_match': '12/09/2026 19:30 Mendo Booischot C - Berg-op Wijgmaal A',
        'is_fav': false,
      },
      {
        'team': 'Mendo Booischot A',
        'series': 'Nationale 2 Dames B',
        'ranking': '2e',
        'next_match':
            '12/09/2026 18:00 Noust Spinley Dessel A - Mendo Booischot A',
        'is_fav': true,
      },
      {
        'team': 'Mendo Booischot D',
        'series': 'Heren Promo 2',
        'ranking': '6e',
        'next_match':
            '13/09/2026 18:00 Mortsel Volley Antwerpen B - Mendo Booischot D',
        'is_fav': false,
      },
      {
        'team': 'Mendo Booischot B',
        'series': 'Dames Promo 1',
        'ranking': '5e',
        'next_match':
            '13/09/2026 13:30 Mendo Booischot B - Mendo Dames Promo Booischot',
        'is_fav': false,
      },
      {
        'team': 'Mendo Booischot C',
        'series': 'Dames Promo 3 B',
        'ranking': '3e',
        'next_match':
            '12/09/2026 16:30 TeamFisk Volley Puurs A - Mendo Booischot C',
        'is_fav': false,
      },
    ],
  };

  static final Map<String, List<Map<String, dynamic>>> clubCupTeams = {
    'Kreg Rotselaar': [
      {
        'team': 'Kreg Rotselaar A',
        'series': 'Beker Vlaams-Brabant Heren',
        'ranking': '',
        'next_match': '25/10/2026 19:30 Kreg Rotselaar A - VC Feniks Haacht A',
        'is_fav': true,
      },
      {
        'team': 'Kreg Rotselaar A',
        'series': 'Beker Vlaams-Brabant Dames',
        'ranking': '',
        'next_match': '01/11/2026 15:00 Kreg Rotselaar A - VBT Machelen A',
        'is_fav': false,
      },
    ],
    'Mendo Booischot': [
      {
        'team': 'Mendo Booischot B (P1)',
        'series': 'Interfederale Beker Dames',
        'ranking': '',
        'next_match':
            '31/10/2026 20:00 Mendo Booischot B (P1) - VC Optima Lier',
        'is_fav': false,
      },
      {
        'team': 'Mendo Booischot (N1)',
        'series': 'Beker van Antwerpen Heren',
        'ranking': '',
        'next_match': '19/12/2026 20:00 VC Geel - Mendo Booischot (N1)',
        'is_fav': false,
      },
      {
        'team': 'Mendo Booischot (N2) +4',
        'series': 'Beker van Antwerpen Dames',
        'ranking': '',
        'next_match':
            '31/10/2026 20:00 Mendo Booischot (N2)+4 - KwadrO Amigos Zoersel',
        'is_fav': false,
      },
    ],
  };

  static final Map<String, List<Map<String, dynamic>>> teamMatches = {
    'Kreg Rotselaar A': [
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'VC Lennik A',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '13/09/2026',
        'match_time': '16:00',
      },
      {
        'home_team': 'Kruikenburg Ternat B',
        'away_team': 'Kreg Rotselaar A',
        'result': null,
        'venue': 'Ternat, Sporthal Kruikenburg',
        'time': '19/09/2026',
        'match_time': '20:30',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'VBT Machelen B',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '27/09/2026',
        'match_time': '16:00',
      },
      {
        'home_team': 'Zuun Volleybal Club A',
        'away_team': 'Kreg Rotselaar A',
        'result': null,
        'venue': 'Sint-Pieters-Leeuw, Wildersportcomplex',
        'time': '02/10/2026',
        'match_time': '21:00',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'Wolvertem Sporting A',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '11/10/2026',
        'match_time': '16:00',
      },
      {
        'home_team': 'Davoc Lot',
        'away_team': 'Kreg Rotselaar A',
        'result': null,
        'venue': 'Lot, Vogelenzang',
        'time': '23/10/2026',
        'match_time': '21:00',
      },
      {
        'home_team': 'Volley Opwijk',
        'away_team': 'Kreg Rotselaar A',
        'result': null,
        'venue': 'Opwijk, Sportzaal VKO',
        'time': '07/11/2026',
        'match_time': '21:00',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'VC Feniks Haacht B',
        'result': '3-1',
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '15/11/2026',
        'match_time': '16:00',
      },
      {
        'home_team': 'Volley Haasrode Leuven D',
        'away_team': 'Kreg Rotselaar A',
        'result': null,
        'venue': 'Haasrode, Sportcomplex',
        'time': '20/11/2026',
        'match_time': '21:00',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'Lizards Lubbeek-Leuven B',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '06/12/2026',
        'match_time': '16:00',
      },
      {
        'home_team': 'VC Lennik A',
        'away_team': 'Kreg Rotselaar A',
        'result': null,
        'venue': 'Lennik, Sporthal Jo Baetens',
        'time': '02/01/2027',
        'match_time': '20:30',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'Kruikenburg Ternat B',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '10/01/2027',
        'match_time': '16:00',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'Zuun Volleybal Club A',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '24/01/2027',
        'match_time': '16:00',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'Davoc Lot',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '21/02/2027',
        'match_time': '16:00',
      },
      {
        'home_team': 'Kreg Rotselaar A',
        'away_team': 'Volley Eternit Kapelle-Op-Den-Bos B',
        'result': null,
        'venue': 'Rotselaar, Sportoase De Meander',
        'time': '28/03/2027',
        'match_time': '16:00',
      },
    ],
    'Mendo Booischot B': [
      {
        'home_team': 'Mavo Dilsen-Stokkem A',
        'away_team': 'Mendo Booischot B',
        'result': null,
        'venue': 'Dilsen-Stokkem, Sporthal',
        'time': '12/09/2026',
        'match_time': '20:00',
      },
      {
        'home_team': 'Mendo Booischot B',
        'away_team': 'VC Achel A',
        'result': null,
        'venue': 'Booischot, Sporthal Mendo',
        'time': '20/09/2026',
        'match_time': '20:00',
      },
      {
        'home_team': 'VOC Herentals A',
        'away_team': 'Mendo Booischot B',
        'result': null,
        'venue': 'Herentals, Sporthal',
        'time': '03/10/2026',
        'match_time': '21:00',
      },
      {
        'home_team': 'Mendo Booischot B',
        'away_team': 'Vlimmeren Sport A',
        'result': null,
        'venue': 'Booischot, Sporthal Mendo',
        'time': '18/10/2026',
        'match_time': '20:00',
      },
      {
        'home_team': 'Mendo Booischot B',
        'away_team': 'VC Maasmechelen A',
        'result': null,
        'venue': 'Booischot, Sporthal Mendo',
        'time': '08/11/2026',
        'match_time': '20:00',
      },
      {
        'home_team': 'Turnhout A',
        'away_team': 'Mendo Booischot B',
        'result': null,
        'venue': 'Turnhout, Sporthal',
        'time': '06/12/2026',
        'match_time': '20:00',
      },
    ],
    'Mendo Booischot A': [
      {
        'home_team': 'Noust Spinley Dessel A',
        'away_team': 'Mendo Booischot A',
        'result': null,
        'venue': 'Dessel, Sporthal',
        'time': '12/09/2026',
        'match_time': '18:00',
      },
      {
        'home_team': 'Mendo Booischot A',
        'away_team': 'VC Beveren A',
        'result': null,
        'venue': 'Booischot, Sporthal Mendo',
        'time': '27/09/2026',
        'match_time': '20:00',
      },
      {
        'home_team': 'VOS Tessenderlo A',
        'away_team': 'Mendo Booischot A',
        'result': null,
        'venue': 'Tessenderlo, Sporthal',
        'time': '10/10/2026',
        'match_time': '21:00',
      },
      {
        'home_team': 'Mendo Booischot A',
        'away_team': 'Dynamo Heusden-Zolder A',
        'result': null,
        'venue': 'Booischot, Sporthal Mendo',
        'time': '25/10/2026',
        'match_time': '20:00',
      },
      {
        'home_team': 'Mendo Booischot A',
        'away_team': 'VCB Dilsen A',
        'result': null,
        'venue': 'Booischot, Sporthal Mendo',
        'time': '15/11/2026',
        'match_time': '20:00',
      },
    ],
  };
}
