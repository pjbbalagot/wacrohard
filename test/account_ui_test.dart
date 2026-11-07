import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tulai/core/brand_theme.dart';
import 'package:tulai/core/providers.dart';
import 'package:tulai/features/auth/auth_screen.dart';

class AccountAuth implements GoTrueClient {
  @override
  User? currentUser = const User(
      id: 'test-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-11-07T08:00:00Z',
      email: 'learner@example.com');
  int signOutCalls = 0;
  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AccountClient implements SupabaseClient {
  @override
  final AccountAuth auth = AccountAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Account email is prominent and sign out requires confirmation',
      (tester) async {
    final client = AccountClient();
    await tester.pumpWidget(ProviderScope(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
        child: MaterialApp(theme: Brand.light, home: const AuthScreen())));
    await tester.pumpAndSettle();
    final email = tester.widget<Text>(find.text('learner@example.com'));
    expect(email.style!.fontSize, 22);
    expect(email.style!.fontWeight, FontWeight.w800);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign out'));
    expect(button.style!.backgroundColor!.resolve({}), const Color(0xFFBA1A1A));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(client.auth.signOutCalls, 0);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(client.auth.signOutCalls, 1);
    expect(find.text('learner@example.com'), findsNothing);
  });
}
