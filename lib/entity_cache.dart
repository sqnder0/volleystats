import 'dart:async';

/// A capped, disk-persisted in-memory cache keyed by id, with throttled
/// writeback and an explicit invalidate() - the pattern TeamModel/ClubModel
/// both need, previously duplicated as two near-identical Map + eviction +
/// persist-timer blocks in main.dart.
///
/// Refreshing an entry is always "invalidate() then reload", never an
/// ambient flag threaded through widget state - that pattern (a
/// _forceReloadPending bool read at build time) is what caused
/// ClubDetailPage's pull-to-refresh to silently serve stale team data: the
/// flag got reset before the rebuild that needed to read it.
class EntityCache<T> {
  final int maxSize;
  final Future<void> Function(Map<String, dynamic> json)? persist;
  final Map<String, dynamic> Function(T value)? toJson;
  final Duration persistDelay;

  final Map<String, T> _entries = {};
  Timer? _persistTimer;

  EntityCache({
    this.maxSize = 100,
    this.persist,
    this.toJson,
    this.persistDelay = const Duration(seconds: 2),
  });

  T? get(String key) => _entries[key];

  bool containsKey(String key) => _entries.containsKey(key);

  void put(String key, T value) {
    _entries[key] = value;
    if (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
    _schedulePersist();
  }

  /// Loads an entry from disk without triggering a persist write-back (it
  /// just came from disk, so there's nothing new to save).
  void restore(String key, T value) {
    _entries[key] = value;
  }

  void invalidate(String key) => _entries.remove(key);

  void invalidateAll() => _entries.clear();

  void _schedulePersist() {
    final persistFn = persist;
    final toJsonFn = toJson;
    if (persistFn == null || toJsonFn == null) return;

    _persistTimer?.cancel();
    _persistTimer = Timer(persistDelay, () {
      final jsonMap = <String, dynamic>{};
      _entries.forEach((key, value) => jsonMap[key] = toJsonFn(value));
      persistFn(jsonMap);
    });
  }
}
