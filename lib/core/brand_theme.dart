import 'package:flutter/material.dart';

abstract final class Brand {
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0050BF);
  static const blue = Color(0xFF39AFE6);
  static const orange = Color(0xFFF58320);
  static const yellow = Color(0xFFFFC51C);
  static const ink = Color(0xFF142D51);
  static const muted = Color(0xFF61718A);
  static const canvas = Color(0xFFF5F8FE);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: navy).copyWith(
      primary: navy,
      onPrimary: white,
      secondary: blue,
      onSecondary: ink,
      tertiary: orange,
      onTertiary: ink,
      surface: white,
      onSurface: ink,
      surfaceContainerHighest: const Color(0xFFEDF3FD),
      error: const Color(0xFFBA1A1A),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE5ECF7))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFDCE5F3))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFDCE5F3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: navy, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: blue.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected) ? navy : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500)),
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/tulai_logo.png',
            height: 42,
            width: 42,
            fit: BoxFit.contain,
            semanticLabel: 'TULAI logo'),
        const SizedBox(width: 9),
        const Text('TULAI',
            style: TextStyle(
                fontFamily: 'Roboto',
                color: Brand.navy,
                fontWeight: FontWeight.w900,
                fontSize: 25,
                letterSpacing: 1.4)),
      ]));
}
