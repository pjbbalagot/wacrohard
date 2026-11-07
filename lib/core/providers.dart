import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_store.dart';
import '../data/repositories.dart';

final storeProvider = Provider((ref) => LocalStore.instance);
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
final repositoryProvider = Provider((ref) => LearningRepository(ref.watch(storeProvider), ref.watch(supabaseClientProvider)));
final languageProvider = StateProvider<String>((ref) => 'en');
final contentLanguageProvider = StateProvider<String>((ref) => 'en');
final catalogueProvider = FutureProvider((ref) => ref.watch(repositoryProvider).resources());
final assessmentHistoryProvider = FutureProvider((ref) => ref.watch(repositoryProvider).assessmentHistory());
final recentActivitiesProvider = FutureProvider((ref) => ref.watch(repositoryProvider).recentActivities());
final progressProvider = FutureProvider((ref) => ref.watch(repositoryProvider).overallProgress());
