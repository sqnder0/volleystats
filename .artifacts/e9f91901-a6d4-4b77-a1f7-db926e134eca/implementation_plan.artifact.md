# Implementation Plan - Dynamic Rankings & League Caching

This plan transitions the Rankings page to use dynamic API data, introduces a `LeagueModel` for structured data and caching, and adds a refresh mechanism.

## Proposed Changes

### [VolleyStats UI]

#### [MODIFY] [ranking_row.dart](file:///home/sander/StudioProjects/volleystats/lib/ranking_row.dart)
- Update `VRankingRow` to accept `String position` instead of `int position` to support API values like "01", "04a", etc.

### [VolleyStats Core]

#### [MODIFY] [main.dart](file:///home/sander/StudioProjects/volleystats/lib/main.dart)

- **Cache Layer**: Add `_leagueCache` to store `LeagueModel` instances.
- **`LeagueModel` [NEW]**:
    - Fields: `series`, `seriesId`, `ranking` (List), `alert`.
    - Factory `fromJson`.
    - Static method `load(String label, {bool forceReload})` to fetch data and manage cache.
- **`_RankingsPageState`**:
    - State variables for available leagues (from favorites), selected league, and loading states.
    - Implement `_initializeLeagues()`:
        1. Fetch favorite teams.
        2. Extract unique leagues using `team.leagueId` and `team.leagueName`.
        3. Store as `List<Map<String, String>>` (id, name, fullLabel).
    - Implement `_loadRanking({bool forceReload = false})`:
        - Use `LeagueModel.load` with the selected league's label.
    - **Refresh Mechanism**: Wrap the ranking list in a `RefreshIndicator` to allow users to force a reload of the current league.
    - Update `build()` to handle:
        - Loading leagues (initial).
        - Loading ranking (on change or refresh).
        - Displaying "Alert" from API (e.g., "Ranking not available").
        - Showing a "No favorite teams" empty state.

## Verification Plan

### Manual Verification
- **Initial Load**: Verify the page identifies leagues from favorites and loads the first one.
- **League Switching**: Change the league via dropdown and verify the new ranking loads.
- **Pull-to-Refresh**: Swipe down on the ranking list and verify `LeagueModel.load` is called with `forceReload: true`.
- **Data Integrity**: Confirm stats (Wins, Losses, Sets, Points) are mapped correctly from the API's granular win/loss types.
- **Favorite Highlighting**: Ensure teams from your favorites list are highlighted in the ranking.
