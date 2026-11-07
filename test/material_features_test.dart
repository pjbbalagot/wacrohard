import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulai/core/providers.dart';
import 'package:tulai/data/local_store.dart';
import 'package:tulai/data/repositories.dart';
import 'package:tulai/features/catalog/catalog_screen.dart';
import 'package:tulai/features/reader/read_aloud.dart';

final lesson = <String, Object?>{
  'id': 'generated-1',
  'title': 'Fractions',
  'description': 'Parts of a whole',
  'subject': 'Mathematics',
  'difficulty': 'Beginner',
  'language': 'en',
  'content': '# Fractions\nOne half.',
  'content_type': 'ai_generated',
  'remote_managed': 0,
};

class FakeStore implements LocalStore {
  bool deleted = false;
  @override
  Future<bool> deleteGeneratedResource(String id) async {
    deleted = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRepository extends LearningRepository {
  FakeRepository(this.fake) : super(fake);
  final FakeStore fake;
  String? lastQuery, lastSubject, lastDifficulty;
  @override
  Future<void> refreshCatalogue() async {}
  @override
  Future<List<Map<String, Object?>>> resources(
      {String? query,
      String? subject,
      String? language,
      String? difficulty}) async {
    lastQuery = query;
    lastSubject = subject;
    lastDifficulty = difficulty;
    return fake.deleted ||
            (query?.isNotEmpty == true &&
                !'Fractions'.toLowerCase().contains(query!.toLowerCase())) ||
            (subject != null && subject != 'All' && subject != 'Mathematics') ||
            (difficulty != null && difficulty != 'Beginner')
        ? []
        : [lesson];
  }

  @override
  Future<List<Map<String, Object?>>> recommendations(
          {String language = 'en'}) async =>
      [lesson];
}

void main() {
  test('Markdown is read as text without formatting or link URLs', () {
    expect(
        spokenText(
            '# Title\n\nRead **carefully** and [learn](https://example.com).'),
        'Title\n\nRead carefully and learn.');
  });

  for (final recommended in [false, true]) {
    testWidgets('Filters apply and reset (recommended: $recommended)',
        (tester) async {
      final fake = FakeStore();
      final repo = FakeRepository(fake);
      await tester.pumpWidget(ProviderScope(overrides: [
        repositoryProvider.overrideWithValue(repo),
        storeProvider.overrideWithValue(fake),
      ], child: MaterialApp(home: CatalogScreen(recommended: recommended))));
      await tester.pumpAndSettle();
      expect(find.text('Fractions'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no match');
      await tester.pumpAndSettle();
      expect(repo.lastQuery, 'no match');
      expect(find.text('Fractions'), findsNothing);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Fractions'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(repo.lastSubject, 'English');
      expect(find.text('Fractions'), findsNothing);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intermediate').last);
      await tester.pumpAndSettle();
      expect(repo.lastDifficulty, 'Intermediate');
      expect(find.text('Fractions'), findsNothing);
    });
  }

  testWidgets('Generated material deletion can be cancelled or confirmed',
      (tester) async {
    final fake = FakeStore();
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(FakeRepository(fake)),
      storeProvider.overrideWithValue(fake),
    ], child: const MaterialApp(home: CatalogScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete generated material'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.deleted, false);
    expect(find.text('Fractions'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete generated material'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(fake.deleted, true);
    expect(find.text('Fractions'), findsNothing);
  });

  testWidgets(
      'Read aloud selects material language, speaks plain text and stops',
      (tester) async {
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'getLanguages' ? ['en-US', 'fil-PH'] : 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ReadAloud(
                content: '# Aralin\n\n**Kumusta**', language: 'fil'))));
    await tester.tap(find.text('Read aloud'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'setLanguage').single.arguments,
        'fil-PH');
    expect(calls.where((c) => c.method == 'speak').single.arguments,
        'Aralin\n\nKumusta');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.any((c) => c.method == 'stop'), true);
  });
}
