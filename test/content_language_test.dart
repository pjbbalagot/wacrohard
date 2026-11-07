import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulai/core/brand_theme.dart';
import 'package:tulai/core/providers.dart';
import 'package:tulai/features/dashboard/home_screen.dart';
import 'package:tulai/features/ai/ai_discovery_screen.dart';
import 'ui_refresh_test.dart' show UiStore;
import 'material_features_test.dart' show FakeRepository, FakeStore;

void main() {
  testWidgets('All languages preference is saved and shown in the library',
      (tester) async {
    final store = UiStore();
    await tester.pumpWidget(ProviderScope(overrides: [
      storeProvider.overrideWithValue(store),
      repositoryProvider.overrideWithValue(FakeRepository(FakeStore())),
      progressProvider.overrideWith((ref) async => 0.0),
      assessmentHistoryProvider.overrideWith((ref) async => []),
      recentActivitiesProvider.overrideWith((ref) async => []),
    ], child: MaterialApp(theme: Brand.light, home: const HomeScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All languages').last);
    await tester.pumpAndSettle();
    expect(store.prefs['content_language'], 'all');
    final dropdowns = tester
        .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .toList();
    expect(dropdowns.first.value, 'en');
    expect(dropdowns.last.value, 'all');
    Navigator.of(tester.element(find.text('Learning-content language'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();
    expect(find.text('All languages'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI generation has a specific language when preference is all',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          contentLanguageProvider.overrideWith((ref) => 'all'),
        ],
        child:
            MaterialApp(theme: Brand.light, home: const AiDiscoveryScreen())));
    await tester.pumpAndSettle();
    final languages = tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(languages.last.initialValue, 'en');
    expect(tester.takeException(), isNull);
  });
}
