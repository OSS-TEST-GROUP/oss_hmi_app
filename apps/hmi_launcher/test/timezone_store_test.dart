import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/timezone_store.dart';

void main() {
  group('TimezoneStore', () {
    test('defaults to Korea (KST, +9) when nothing stored', () {
      final store = TimezoneStore.inMemory();
      expect(store.selectedId, 'Asia/Seoul');
      expect(store.selected.offsetMinutes, 9 * 60);
    });

    test('now() is UTC + selected offset', () {
      final store = TimezoneStore.inMemory(); // KST +9
      final delta = store.now().difference(DateTime.now().toUtc());
      // Within a second of +9h regardless of host timezone.
      expect((delta - const Duration(hours: 9)).abs().inSeconds, lessThan(2));
    });

    test('select() switches zone and persists across load()', () async {
      final store = TimezoneStore.inMemory();
      await store.select('Etc/UTC');
      expect(store.selectedId, 'Etc/UTC');
      expect(store.selected.offsetMinutes, 0);

      // A fresh store sharing the same backing reads the persisted choice.
      // (inMemory keeps its own closure, so verify persistence via load path:)
      // select() already persisted; reload should keep UTC.
      await store.load();
      expect(store.selectedId, 'Etc/UTC');
    });

    test('unknown id falls back to Korea', () async {
      final store = TimezoneStore.inMemory();
      await store.select('Mars/Olympus');
      expect(store.selectedId, 'Asia/Seoul');
    });

    test('notifies listeners on change', () async {
      final store = TimezoneStore.inMemory();
      var fired = 0;
      store.addListener(() => fired++);
      await store.select('Asia/Tokyo');
      expect(fired, greaterThan(0));
      // No-op select (same zone) does not notify again.
      final before = fired;
      await store.select('Asia/Tokyo');
      expect(fired, before);
    });

    test('IST has a half-hour offset (+5:30)', () {
      final store = TimezoneStore.inMemory(initialId: 'Asia/Kolkata');
      expect(store.selected.offsetMinutes, 5 * 60 + 30);
    });
  });
}
