import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/model/key_value_item.dart';

void main() {
  test('KeyValueItem stores keyLabel and value correctly', () {

    const key = 'Speed';
    const value = '100 km/h';

    final item = KeyValueItem(keyLabel: key, value: value);

    expect(item.keyLabel, key);
    expect(item.value, value);
  });
}
