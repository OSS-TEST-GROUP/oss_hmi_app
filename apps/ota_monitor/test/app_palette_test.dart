// QA(docs/qa): ota_monitor Palette — dark/light 인스턴스 + fromName + ThemeData.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_monitor/theme/app_palette.dart';

void main() {
  test('dark/light 팔레트는 서로 다른 밝기/색', () {
    expect(Palette.dark.brightness, Brightness.dark);
    expect(Palette.light.brightness, Brightness.light);
    expect(Palette.dark.name, 'dark');
    expect(Palette.light.name, 'light');
    // 주요 색 필드 접근(값 존재 확인).
    expect(Palette.dark.background, isNot(Palette.light.background));
    expect(Palette.light.primary, isA<Color>());
    expect(Palette.light.textPrimary, isA<Color>());
    expect(Palette.dark.error, isA<Color>());
    expect(Palette.dark.success, isA<Color>());
    expect(Palette.light.warning, isA<Color>());
  });

  test('fromName: dark/light/기타/null 매핑', () {
    expect(Palette.fromName('dark').name, 'dark');
    expect(Palette.fromName('light').name, 'light');
    expect(Palette.fromName('unknown').name, 'light'); // default
    expect(Palette.fromName(null).name, 'light'); // default
  });
}
