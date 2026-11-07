import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulai/features/reader/read_aloud.dart';

void main() {
  testWidgets('Read aloud is disabled for materials without local text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ReadAloud(content: '', language: 'en'))));
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });
}
