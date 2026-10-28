import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'viewmodels/providers.dart';
import 'views/home_view.dart';
import 'views/splash_view.dart';
import 'views/widgets/design_system.dart';

class CellScopeApp extends StatelessWidget {
  final CellScopeApi? api;
  const CellScopeApp({super.key, this.api});

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      if (api != null)
        apiProvider.overrideWith((ref) {
          ref.onDispose(api!.close);
          return api!;
        }),
    ],
    child: MaterialApp(
      title: 'CellScope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: emeraldDarkest,
        colorScheme: const ColorScheme.dark(
          primary: emeraldBright,
          secondary: emeraldAccent,
          surface: Color(0xFF052B1E),
          onPrimary: Color(0xFF012015),
          onSurface: textPrimary,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: textPrimary,
          displayColor: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0x33000000),
          labelStyle: const TextStyle(color: emeraldMint, fontSize: 14),
          helperStyle: const TextStyle(color: emeraldMint, fontSize: 11),
          hintStyle: const TextStyle(color: textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x3334D399)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x3334D399)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: emeraldBright, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: emeraldBright,
            foregroundColor: const Color(0xFF012417),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            elevation: 4,
            shadowColor: const Color(0x4034D399),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: emeraldBright,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF04261B),
          elevation: 16,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x3334D399)),
          ),
          titleTextStyle: const TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF021B14),
          modalBackgroundColor: Color(0xFF021B14),
          elevation: 16,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
      ),
      home: const SplashView(child: Home()),
    ),
  );
}
