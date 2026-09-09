import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/services/data_cache.dart';

void main() {
  group('DataCache Tests', () {
    test('instance returns singleton', () {
      final a = DataCache.instance;
      final b = DataCache.instance;
      expect(identical(a, b), isTrue);
    });

    test('update sets new data and notifies listeners', () {
      final cache = DataCache.instance;
      Map<String, dynamic>? notified;

      void listener() {
        notified = cache.last;
      }

      cache.listenable.addListener(listener);

      cache.update({'Vehicle.Speed': 85.5, 'UserID': 'user1'});

      expect(cache.last['Vehicle.Speed'], 85.5);
      expect(cache.last['UserID'], 'user1');
      expect(notified?['Vehicle.Speed'], 85.5);

      cache.listenable.removeListener(listener);
    });
  });
}
