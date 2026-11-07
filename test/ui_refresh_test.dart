import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulai/core/brand_theme.dart';
import 'package:tulai/core/providers.dart';
import 'package:tulai/data/local_store.dart';
import 'package:tulai/features/dashboard/home_screen.dart';
import 'package:tulai/features/reader/reader_screen.dart';
import 'package:tulai/features/catalog/catalog_screen.dart';
import 'material_features_test.dart' as fixtures;

class UiStore implements LocalStore {
  final prefs = <String, String>{};
  @override
  Future<String?> preference(String key) async => prefs[key];
  @override
  Future<void> setPreference(String key, String value) async {
    prefs[key] = value;
  }

  @override
  Future<Map<String, Object?>?> progressFor(String id) async => null;
  @override
  Future<String?> approvedAccountId(String? user) async => null;
  @override
  Future<void> saveProgress(String id, int position, double percent,
      {String? ownerUserId}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> savePreview(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/ui-previews').create(recursive: true);
    await File('build/ui-previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    // Local preview fonts are optional; assertions also run with Flutter's test font.
    final systemFont = File('C:/Windows/Fonts/segoeui.ttf');
    if (systemFont.existsSync()) {
      final font = FontLoader('Roboto')
        ..addFont(
            Future.value(ByteData.sublistView(await systemFont.readAsBytes())));
      await font.load();
    }
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final iconFile = File(
          '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final icons = FontLoader('MaterialIcons')
          ..addFont(
              Future.value(ByteData.sublistView(await iconFile.readAsBytes())));
        await icons.load();
      }
    }
  });
  for (final width in [390.0, 320.0]) {
    testWidgets('Homepage hierarchy fits a $width phone', (tester) async {
      tester.view.physicalSize = Size(width, 980);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            storeProvider.overrideWithValue(UiStore()),
            repositoryProvider.overrideWithValue(
                fixtures.FakeRepository(fixtures.FakeStore())),
            progressProvider.overrideWith((ref) async => 64.0),
            assessmentHistoryProvider.overrideWith((ref) async => [
                  {
                    'subject': 'Mathematics',
                    'score': 80,
                    'level': 'Proficient',
                    'created_at': '2026-11-07T08:00:00Z'
                  },
                  {
                    'subject': 'English',
                    'score': 65,
                    'level': 'Intermediate',
                    'created_at': '2026-11-06T08:00:00Z'
                  },
                ]),
            recentActivitiesProvider.overrideWith((ref) async => [
                  {
                    'resource_title': 'Foundational Mathematics',
                    'created_at': '2026-11-07T08:00:00Z'
                  },
                ]),
          ],
          child: MaterialApp(
              theme: Brand.light,
              home: const RepaintBoundary(
                  key: ValueKey('preview'), child: HomeScreen()))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('64%'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Data status'), findsNothing);
      final mathCard = find
          .ancestor(of: find.text('Mathematics'), matching: find.byType(Card))
          .first;
      final englishCard = find
          .ancestor(of: find.text('English'), matching: find.byType(Card))
          .first;
      expect(tester.getSize(mathCard), tester.getSize(englishCard));
      expect(tester.getTopLeft(mathCard).dy, tester.getTopLeft(englishCard).dy);
      expect(tester.getCenter(find.text('Mathematics')).dx,
          closeTo(tester.getCenter(mathCard).dx, 0.1));
      expect(tester.getCenter(find.text('English')).dx,
          closeTo(tester.getCenter(englishCard).dx, 0.1));
      final progressY =
          tester.getTopLeft(find.text('Your learning progress')).dy;
      final proficiencyY =
          tester.getTopLeft(find.text('Proficiency results')).dy;
      final startY = tester.getTopLeft(find.text('Start learning')).dy;
      expect(progressY, lessThan(proficiencyY));
      expect(proficiencyY, lessThan(startY));
      if (width == 390) {
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/images/tulai_logo.png'),
            tester.element(find.byType(BrandTitle))));
        await tester.pumpAndSettle();
        await savePreview(tester, 'home');
      }
      await tester.scrollUntilVisible(
          find.text('Foundational Mathematics'), 250);
      expect(find.text('Foundational Mathematics'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Fractions');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(
          find.text('Foundational Mathematics').hitTestable(), findsOneWidget);
      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Fractions');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Reader dark mode uses white text and persists appearance',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = UiStore();
    await tester.pumpWidget(ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: MaterialApp(
            theme: Brand.light,
            home: const RepaintBoundary(
                key: ValueKey('preview'),
                child: ReaderScreen(resource: {
                  'id': 'test',
                  'title': 'Foundational Mathematics',
                  'language': 'en',
                  'content_type': 'platform',
                  'source_name': 'TULAI',
                  'license': 'CC BY 4.0',
                  'content':
                      '# Learning objectives\n\nBuild confidence with numbers.\n\n- Add whole numbers\n- Multiply with confidence\n\n## Addition\n\nTwelve plus eight equals twenty.',
                })))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reading appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.styleSheet!.p!.color, Colors.white);
    expect(store.prefs['reading_appearance'], 'dark');
    expect(tester.takeException(), isNull);
    await savePreview(tester, 'reader-dark');
  });
  testWidgets('Library distinguishes generated modules and fits narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = fixtures.FakeStore();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          repositoryProvider.overrideWithValue(fixtures.FakeRepository(store)),
        ],
        child: MaterialApp(
            theme: Brand.light,
            home: const RepaintBoundary(
                key: ValueKey('preview'), child: CatalogScreen()))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await savePreview(tester, 'library');
  });
}
