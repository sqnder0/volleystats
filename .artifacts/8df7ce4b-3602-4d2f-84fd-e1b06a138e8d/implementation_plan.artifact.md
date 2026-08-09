# Implementation Plan: Splash & Loading Screen Refinement

This plan addresses the "chopped" native splash icon and improves the Flutter loading screen to match the app's "empty state" aesthetic. It also ensures the "No Favorites" screen is correctly centered.

## User Review Required

> [!IMPORTANT]
> **Splash Icon Scaling**: To prevent the Android 12 splash icon from being chopped, I will adjust the `flutter_native_splash` configuration to treat your icon as a foreground layer with proper padding. I will also use a generic volleyball icon for the splash if you prefer, or we can use a smaller version of your logo.
>
> **Loading Screen Aesthetic**: I will update the `VLoadingPage` to use a "greyed" volleyball icon and a layout identical to your `VEmptyState` (Icon + Title + Subtitle), replacing the current simple spinner.

## Proposed Changes

### UI Components

#### [MODIFY] [VLoadingPage in lib/main.dart](file:///home/sander/StudioProjects/volleystats/lib/main.dart)
*   Update `VLoadingPage` to use a `Column` with a `sports_volleyball` icon (or `bar_chart`), themed with `secondary` color.
*   Add a `CircularProgressIndicator` below the icon or as a subtle overlay to maintain the "loading" feedback.
*   Ensure the layout matches `VEmptyState` exactly for visual consistency.

#### [MODIFY] [FavoritesPage in lib/main.dart](file:///home/sander/StudioProjects/volleystats/lib/main.dart)
*   Adjust the centering logic for `VEmptyState` in the `FavoritesPage`. If the header ("Favorieten") is still visible, the empty state might look off-center. I will ensure it occupies the full screen height if it's the only content.

### Project Configuration

#### [MODIFY] [pubspec.yaml](file:///home/sander/StudioProjects/volleystats/pubspec.yaml)
*   Refine `flutter_native_splash` configuration for Android 12.
*   Use `android_12_icon_foreground` to provide the icon separately from the background, which allows the OS to handle scaling and masking without "chopping" the edges.

## Verification Plan

### Automated Tests
*   `flutter pub run flutter_native_splash:create` to regenerate native assets.

### Manual Verification
*   **Splash Screen**: Verify that the icon on the Android 12 splash screen is no longer clipped at the edges.
*   **Loading Screen**: Verify that the "Laden..." screen now features a volleyball icon and matches the empty state style.
*   **Favorites**: Verify that the "Geen favorieten" message is perfectly centered in the view.
