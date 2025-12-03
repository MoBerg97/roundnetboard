import 'package:flutter/material.dart';

/// Centralized theme configuration for RoundnetBoard app.
///
/// Provides a cohesive color palette, Material 3 theming, and consistent
/// styling across all screens and components.
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // Color Palette - Modern Roundnet/Sports Theme

  /// Primary brand color - vibrant roundnet green
  static const Color primaryGreen = Color(0xFF00C853);

  /// Secondary action color - blue for interactive elements
  static const Color secondaryBlue = Color(0xFF2196F3);

  /// Accent color - orange for energy and highlights
  static const Color accentOrange = Color(0xFFFF6F00);

  /// Dark grey for text and icons
  static const Color darkGrey = Color(0xFF37474F);

  /// Light grey for backgrounds and dividers
  static const Color lightGrey = Color(0xFFECEFF1);

  /// Error red for destructive actions
  static const Color errorRed = Color(0xFFD32F2F);

  /// Success green for positive feedback
  static const Color successGreen = Color(0xFF388E3C);

  /// Warning amber for cautions
  static const Color warningAmber = Color(0xFFFFA726);

  // Court colors for board rendering

  /// Court surface green
  static const Color courtGreen = Color(0xFF4CAF50);

  /// Court line white
  static const Color courtLine = Color(0xFFFFFFFF);

  /// Net circle black
  static const Color netBlack = Color(0xFF212121);

  /// Player colors (customizable via settings)
  static const List<Color> playerColors = [
    Color(0xFF1976D2), // Blue
    Color(0xFFD32F2F), // Red
    Color(0xFFFBC02D), // Yellow
    Color(0xFF7B1FA2), // Purple
  ];

  /// Ball color
  static const Color ballColor = Color(0xFFFBC02D); // Yellow

  /// Creates the light theme for the app using Material 3 design.
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: secondaryBlue,
        tertiary: accentOrange,
        error: errorRed,
        surface: Colors.white,
        brightness: Brightness.light,
      ),

      // App bar styling
      appBarTheme: const AppBarTheme(
        elevation: 2,
        centerTitle: false,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
      ),

      // Card styling
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        clipBehavior: Clip.antiAlias,
      ),

      // Floating action button styling
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Elevated button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Text button styling
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input decoration styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: lightGrey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Icon button styling
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),

      // Slider styling
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryGreen,
        thumbColor: primaryGreen,
        overlayColor: Color(0x2900C853), // primaryGreen with alpha
      ),

      // Dialog styling
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        elevation: 8,
      ),

      // List tile styling
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 4,
      ),
    );
  }

  /// Creates a dark theme for the app (future implementation).
  ///
  /// This can be implemented later to support dark mode preferences.
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: secondaryBlue,
        tertiary: accentOrange,
        error: errorRed,
        surface: const Color(0xFF1E1E1E),
        brightness: Brightness.dark,
      ),
      // Additional dark theme customizations can be added here
    );
  }
}
