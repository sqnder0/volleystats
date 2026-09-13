import 'package:flutter_test/flutter_test.dart';
import 'package:volleystats/entity_cache.dart';

void main() {
  group('EntityCache', () {
    test('get returns null for a key that was never put', () {
      final cache = EntityCache<String>();
      expect(cache.get('missing'), null);
    });

    test('put then get returns the stored value', () {
      final cache = EntityCache<String>();
      cache.put('a', 'value-a');
      expect(cache.get('a'), 'value-a');
    });

    test('invalidate removes just that one entry', () {
      final cache = EntityCache<String>();
      cache.put('a', 'value-a');
      cache.put('b', 'value-b');

      cache.invalidate('a');

      expect(cache.get('a'), null);
      expect(cache.get('b'), 'value-b');
    });

    test('invalidateAll clears every entry', () {
      final cache = EntityCache<String>();
      cache.put('a', 'value-a');
      cache.put('b', 'value-b');

      cache.invalidateAll();

      expect(cache.get('a'), null);
      expect(cache.get('b'), null);
    });

    test('evicts the oldest entry once maxSize is exceeded', () {
      final cache = EntityCache<String>(maxSize: 2);
      cache.put('a', '1');
      cache.put('b', '2');
      cache.put('c', '3'); // should push out 'a', the oldest

      expect(cache.get('a'), null);
      expect(cache.get('b'), '2');
      expect(cache.get('c'), '3');
    });

    test('restore loads a value without scheduling a persist write', () async {
      var persistCalls = 0;
      final cache = EntityCache<String>(
        persist: (json) async {
          persistCalls++;
        },
        toJson: (v) => {'value': v},
        persistDelay: const Duration(milliseconds: 1),
      );

      cache.restore('a', 'from-disk');
      expect(cache.get('a'), 'from-disk');

      await Future.delayed(const Duration(milliseconds: 20));
      expect(
        persistCalls,
        0,
        reason: 'restore() should not trigger a persist write-back',
      );
    });

    test('put schedules a throttled persist with the current entries', () async {
      Map<String, dynamic>? lastPersisted;
      final cache = EntityCache<String>(
        persist: (json) async {
          lastPersisted = json;
        },
        toJson: (v) => {'value': v},
        persistDelay: const Duration(milliseconds: 1),
      );

      cache.put('a', 'value-a');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(lastPersisted, {'a': {'value': 'value-a'}});
    });

    test('rapid puts only persist once, after the delay settles', () async {
      var persistCalls = 0;
      final cache = EntityCache<String>(
        persist: (json) async {
          persistCalls++;
        },
        toJson: (v) => {'value': v},
        persistDelay: const Duration(milliseconds: 20),
      );

      cache.put('a', '1');
      cache.put('a', '2');
      cache.put('a', '3');

      await Future.delayed(const Duration(milliseconds: 50));

      expect(persistCalls, 1);
    });
  });
}
