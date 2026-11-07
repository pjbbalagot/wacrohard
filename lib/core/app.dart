import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/home_screen.dart';
import 'providers.dart';
import 'brand_theme.dart';

class TulaiApp extends ConsumerWidget {
  const TulaiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return MaterialApp(
      title: 'TULAI',
      debugShowCheckedModeBanner: false,

      // Ilocano uses TULAI's own translations.
      // Flutter's built-in Material interface falls back to English.
      locale: Locale(language == 'ilo' ? 'en' : language),

      supportedLocales: const [
        Locale('en'),
        Locale('fil'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: Brand.light,

      home: const HomeScreen(),
    );
  }
}
