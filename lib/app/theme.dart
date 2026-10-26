import 'package:flutter/material.dart';

const canvasColor = Color(0xFF0C1018);
const panelColor = Color(0xFF141B28);
const spiderRed = Color(0xFFF04452);
const secondaryText = Color(0xFF9BA8BC);
ThemeData pautinaTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: canvasColor,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: spiderRed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: spiderRed,
        surface: panelColor,
        onSurface: const Color(0xFFEEF2F8),
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: canvasColor,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panelColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  ),
  cardTheme: CardThemeData(
    color: panelColor,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      backgroundColor: spiderRed,
      foregroundColor: Colors.white,
    ),
  ),
);
