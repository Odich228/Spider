import 'package:flutter/material.dart';

const canvasColor = Color(0xFF0C1018);
const panelColor = Color(0xFF141B28);
const spiderRed = Color(0xFFF04452);
const secondaryText = Color(0xFF9BA8BC);
ThemeData pautinaTheme({bool symbiote = false}) => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: symbiote ? const Color(0xFF06070A) : canvasColor,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: symbiote ? const Color(0xFFBCCBFA) : spiderRed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: symbiote ? const Color(0xFFBCCBFA) : spiderRed,
        surface: symbiote ? const Color(0xFF11131A) : panelColor,
        onSurface: const Color(0xFFEEF2F8),
      ),
  appBarTheme: AppBarTheme(
    backgroundColor: symbiote ? const Color(0xFF06070A) : canvasColor,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: symbiote ? const Color(0xFF11131A) : panelColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  ),
  cardTheme: CardThemeData(
    color: symbiote ? const Color(0xFF11131A) : panelColor,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      backgroundColor: symbiote ? const Color(0xFFBCCBFA) : spiderRed,
      foregroundColor: symbiote ? canvasColor : Colors.white,
    ),
  ),
);
