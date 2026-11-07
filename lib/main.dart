import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app.dart';
import 'core/providers.dart';
import 'data/local_store.dart';
import 'data/sync_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore.instance;
  await store.database;
  await store.seedIfEmpty();
  final interfaceLanguage = await store.preference('interface_language') ?? 'en';
  final contentLanguage = await store.preference('content_language') ?? 'en';
  const url = String.fromEnvironment('SUPABASE_URL');
  const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
  var backendReady = false;
  if (url.isNotEmpty && anon.isNotEmpty) {
    try { await Supabase.initialize(url: url, anonKey: anon); backendReady = true; } catch (_) { backendReady = false; }
  }
  if (backendReady) {
    var syncing = false;
    Future<void> attemptSync() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (syncing || user == null) return;
      final states = await Connectivity().checkConnectivity();
      if (!states.any((state) => state != ConnectivityResult.none)) return;
      syncing = true;
      final sync = SyncService(store, Supabase.instance.client);
      try { await sync.restoreCloudRecords(); } catch (_) { /* Keep the last account cache on network errors. */ }
      try {
        if (await store.approvedAccountId(user.id) == user.id) await sync.migrateApprovedRecords();
      } catch (_) { /* Pending rows remain local and retry on the next connection event. */ }
      finally { syncing = false; }
    }
    Connectivity().onConnectivityChanged.listen((states) {
      if (states.any((state) => state != ConnectivityResult.none)) unawaited(attemptSync());
    });
    Supabase.instance.client.auth.onAuthStateChange.listen((_) => unawaited(attemptSync()));
    unawaited(attemptSync());
  }
  runApp(ProviderScope(overrides: [
    languageProvider.overrideWith((ref) => interfaceLanguage),
    contentLanguageProvider.overrideWith((ref) => contentLanguage),
    if (backendReady) supabaseClientProvider.overrideWithValue(Supabase.instance.client),
  ], child: const TulaiApp()));
}
