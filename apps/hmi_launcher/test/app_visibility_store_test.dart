// F017 AC1/AC2: AppVisibilityStore unit tests.
//
// AC1: Store persists enabled/disabled state and reloads correctly.
// AC2: Disabled apps are excluded from the rendered set.
//
// All tests use in-memory factories so no real filesystem I/O happens.

import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_visibility_store.dart';

void main() {
  group('AppVisibilityStore — AC1 persistence & reload', () {
    test('initially all apps are enabled (empty disabled set)', () {
      final store = AppVisibilityStore.inMemory();
      expect(store.isEnabled('ota_monitor'), isTrue);
      expect(store.isEnabled('adsw_monitor'), isTrue);
      expect(store.isEnabled('any_id'), isTrue);
    });

    test('disable() makes isEnabled return false', () async {
      final store = AppVisibilityStore.inMemory();
      await store.disable('ota_monitor');
      expect(store.isEnabled('ota_monitor'), isFalse);
      expect(store.isEnabled('adsw_monitor'), isTrue);
    });

    test('enable() after disable restores visibility', () async {
      final store = AppVisibilityStore.inMemory();
      await store.disable('ota_monitor');
      await store.enable('ota_monitor');
      expect(store.isEnabled('ota_monitor'), isTrue);
    });

    test('toggle() disables an enabled app', () async {
      final store = AppVisibilityStore.inMemory();
      await store.toggle('lfc_monitor');
      expect(store.isEnabled('lfc_monitor'), isFalse);
    });

    test('toggle() enables a disabled app', () async {
      final store = AppVisibilityStore.inMemory();
      await store.disable('lfc_monitor');
      await store.toggle('lfc_monitor');
      expect(store.isEnabled('lfc_monitor'), isTrue);
    });

    test('state is persisted and survives a simulated reload (AC1)', () async {
      // Simulate the write → reload lifecycle using the in-memory factory.
      // We use a shared storage slot via a closure so both "instances" share
      // the same backing string, mimicking a file on disk.
      String? stored;
      final store1 = AppVisibilityStore(
        readRaw: () => stored,
        writeRaw: (s) async => stored = s,
      );
      await store1.disable('ota_monitor');
      await store1.disable('lfc_monitor');

      // Simulate a second launch with the same persisted data.
      final store2 = AppVisibilityStore(
        readRaw: () => stored,
        writeRaw: (s) async => stored = s,
      );
      await store2.load();

      expect(store2.isEnabled('ota_monitor'), isFalse);
      expect(store2.isEnabled('lfc_monitor'), isFalse);
      expect(store2.isEnabled('adsw_monitor'), isTrue);
    });

    test('re-enable persists and survives reload', () async {
      String? stored;
      final store1 = AppVisibilityStore(
        readRaw: () => stored,
        writeRaw: (s) async => stored = s,
      );
      await store1.disable('ota_monitor');
      await store1.enable('ota_monitor'); // re-enable

      final store2 = AppVisibilityStore(
        readRaw: () => stored,
        writeRaw: (s) async => stored = s,
      );
      await store2.load();

      expect(store2.isEnabled('ota_monitor'), isTrue);
    });

    test('corrupted storage falls back to all-enabled', () async {
      final store = AppVisibilityStore(
        readRaw: () => '{invalid json',
        writeRaw: (s) async {},
      );
      await store.load();
      expect(store.isEnabled('ota_monitor'), isTrue);
    });

    test('missing storage (null read) keeps all-enabled default', () async {
      final store = AppVisibilityStore(
        readRaw: () => null,
        writeRaw: (s) async {},
      );
      await store.load();
      expect(store.isEnabled('anything'), isTrue);
    });

    test('initialDisabled set is respected before load()', () {
      final store = AppVisibilityStore.inMemory(
        initialDisabled: {'adsw_monitor'},
      );
      expect(store.isEnabled('adsw_monitor'), isFalse);
      expect(store.isEnabled('ota_monitor'), isTrue);
    });

    test('notifies listeners on disable and enable', () async {
      final store = AppVisibilityStore.inMemory();
      int notifyCount = 0;
      store.addListener(() => notifyCount++);

      await store.disable('ota_monitor');
      expect(notifyCount, 1);

      await store.enable('ota_monitor');
      expect(notifyCount, 2);
    });

    test('notifies listeners on toggle', () async {
      final store = AppVisibilityStore.inMemory();
      int notifyCount = 0;
      store.addListener(() => notifyCount++);

      await store.toggle('ota_monitor');
      expect(notifyCount, 1);
    });

    test('disable already-disabled is a no-op (no extra notify)', () async {
      final store = AppVisibilityStore.inMemory();
      await store.disable('ota_monitor');

      int notifyCount = 0;
      store.addListener(() => notifyCount++);

      await store.disable('ota_monitor'); // should be no-op
      expect(notifyCount, 0);
    });

    test('enable already-enabled is a no-op (no extra notify)', () async {
      final store = AppVisibilityStore.inMemory();

      int notifyCount = 0;
      store.addListener(() => notifyCount++);

      await store.enable('ota_monitor'); // already enabled — no-op
      expect(notifyCount, 0);
    });

    test('multiple apps can be disabled independently', () async {
      final store = AppVisibilityStore.inMemory();
      await store.disable('ota_monitor');
      await store.disable('adsw_monitor');
      await store.disable('lfc_monitor');

      expect(store.isEnabled('ota_monitor'), isFalse);
      expect(store.isEnabled('adsw_monitor'), isFalse);
      expect(store.isEnabled('lfc_monitor'), isFalse);
      // An app not explicitly disabled stays enabled.
      expect(store.isEnabled('oss_launcher_bot'), isTrue);
    });
  });

  group('AppVisibilityStore — default-disabled apps (OTA Monitor)', () {
    // The production file factory seeds kDefaultDisabled; these tests use the
    // raw constructor with the same seed so no real filesystem is needed.

    test('kDefaultDisabled ships ota_monitor hidden', () {
      expect(AppVisibilityStore.kDefaultDisabled, contains('ota_monitor'));
    });

    // rviz2_panel 은 2026-08-24 부터 기본 노출 — 보드에서 상시 쓰는 화면이라
    // 숨겨 두면 첫 진입에 Manage Apps 를 거쳐야 했다.
    test('신규 설치에서 rviz2_panel 은 노출된다', () async {
      expect(AppVisibilityStore.kDefaultDisabled,
          isNot(contains('rviz2_panel')));
      final store = AppVisibilityStore(
        readRaw: () => null, // no file yet
        writeRaw: (s) async {},
        initialDisabled: Set.from(AppVisibilityStore.kDefaultDisabled),
      );
      await store.load();
      expect(store.isEnabled('rviz2_panel'), isTrue);
    });

    test('fresh install (no state file) → ota_monitor disabled, rest enabled',
        () async {
      final store = AppVisibilityStore(
        readRaw: () => null, // no file yet
        writeRaw: (s) async {},
        initialDisabled: Set.from(AppVisibilityStore.kDefaultDisabled),
      );
      await store.load();
      expect(store.isEnabled('ota_monitor'), isFalse);
      expect(store.isEnabled('adsw_monitor'), isTrue);
      expect(store.isEnabled('lfc_monitor'), isTrue);
    });

    test('user enabling ota_monitor persists and survives reload', () async {
      String? stored;
      final store1 = AppVisibilityStore(
        readRaw: () => stored,
        writeRaw: (s) async => stored = s,
        initialDisabled: Set.from(AppVisibilityStore.kDefaultDisabled),
      );
      await store1.load();
      await store1.enable('ota_monitor');
      expect(store1.isEnabled('ota_monitor'), isTrue);

      // Second launch: the persisted (empty) disabled set wins over defaults.
      final store2 = AppVisibilityStore(
        readRaw: () => stored,
        writeRaw: (s) async => stored = s,
        initialDisabled: Set.from(AppVisibilityStore.kDefaultDisabled),
      );
      await store2.load();
      expect(store2.isEnabled('ota_monitor'), isTrue);
    });

    test('corrupt state file falls back to defaults (ota_monitor stays hidden)',
        () async {
      final store = AppVisibilityStore(
        readRaw: () => '{invalid json',
        writeRaw: (s) async {},
        initialDisabled: Set.from(AppVisibilityStore.kDefaultDisabled),
      );
      await store.load();
      expect(store.isEnabled('ota_monitor'), isFalse);
      expect(store.isEnabled('adsw_monitor'), isTrue);
    });
  });

  group('AppVisibilityStore — AC2 filter integration', () {
    test('visibleApps excludes disabled apps', () async {
      const allIds = ['ota_monitor', 'adsw_monitor', 'lfc_monitor'];
      final store = AppVisibilityStore.inMemory();
      await store.disable('adsw_monitor');

      final visible = allIds.where(store.isEnabled).toList();
      expect(visible, containsAll(['ota_monitor', 'lfc_monitor']));
      expect(visible, isNot(contains('adsw_monitor')));
    });

    test('empty list when all apps are disabled', () async {
      const allIds = ['ota_monitor', 'adsw_monitor'];
      final store = AppVisibilityStore.inMemory();
      for (final id in allIds) {
        await store.disable(id);
      }

      final visible = allIds.where(store.isEnabled).toList();
      expect(visible, isEmpty);
    });

    test('all apps visible when none are disabled', () async {
      const allIds = ['ota_monitor', 'adsw_monitor', 'lfc_monitor'];
      final store = AppVisibilityStore.inMemory();

      final visible = allIds.where(store.isEnabled).toList();
      expect(visible.length, 3);
    });
  });
}
