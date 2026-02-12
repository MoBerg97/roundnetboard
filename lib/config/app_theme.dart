import 'package:flutter/material.dart';

/// Centralized theme configuration for RoundnetBoard app.
///
/// Provides a cohesive color palette, Material 3 theming, and consistent
/// styling across all screens and components.
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // Color Palette - Modern Roundnet/Sports Theme

  /// Primary accent color for UI (buttons, highlights)
  static const Color primaryBlue = Color(0xFF5f797b);

  /// Secondary action color - deeper blue
  static const Color secondaryBlue = Color(0xFF3d405b);

  /// Accent color - orange (used mainly on board)
  static const Color accentOrange = Color(0xFFFF6F00);

  /// Dark grey for app bars and headers
  static const Color darkGrey = Color(0xFF263238);

  /// Medium grey for cards/containers
  static const Color mediumGrey = Color(0xFF263238);

  /// Light grey for backgrounds and dividers
  static const Color lightGrey = Color(0xFFf4f1de);

  /// Court background (very light grey-green)
  static const Color courtBackground = Color(0xFFE9F0E6);

  /// Error red for destructive actions
  static const Color errorRed = Color(0xFFD32F2F);

  /// Success green for positive feedback
  static const Color successGreen = Color(0xFF5D987B);

  /// Warning amber for cautions
  static const Color warningAmber = Color(0xFFe07a5f);

  // Court colors for board rendering (colorful – reserved for board objects)

  /// Court surface green - more subtle, darker, less neon
  static const Color courtGreen = Color.fromARGB(255, 129, 179, 154);

  /// Shared editor palette for annotations, objects, and court elements
  static const List<Color> editorColors = [
    Color(0xFFF4F1DE),
    Color(0xFF99999D),
    Color(0xFF3D405B),
    Color(0xFF5F797B),
    Color(0xFF81B29A),
    Color(0xFF5D987B),
    Color(0xFFE07A5F),
    Color(0xFFF2CC8F),
    Color(0xFFE59B24),
    Color(0xFFCDDC39),
    Color(0xFF3F51B5),
    Color(0xFF795548),
  ];

  /// Court line white
  static const Color courtLine = Color(0xFFFFFFFF);

  /// Net circle black
  static const Color netBlack = Color(0xFF212121);

  /// Player colors (customizable via settings)
  static const List<Color> playerColors = [
    Color(0xFF3D405B), // Deep blue from editor palette
    Color(0xFFE07A5F), // Warm red/orange from editor palette
    Color(0xFFF2CC8F), // Soft yellow from editor palette
    Color(0xFF3F51B5), // Indigo from editor palette
  ];

  /// Ball color
  static const Color ballColor = Color(0xFFF2CC8F); // Soft yellow from editor palette

  // Timeline colors (UI grey + blue accents)
  static const Color timelineBackground = lightGrey;
  static const Color timelineInactive = Color(0xFFB0BEC5); // blue-grey 200
  static const Color timelineActive = primaryBlue;

  /// Creates the light theme for the app using Material 3 design.
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: secondaryBlue,
        tertiary: accentOrange,
        error: errorRed,
        surface: lightGrey,
        brightness: Brightness.light,
      ),

      // App bar styling
      appBarTheme: const AppBarTheme(
        elevation: 2,
        centerTitle: false,
        backgroundColor: darkGrey,
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
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Elevated button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
        ),
      ),

      // Text button styling
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: primaryBlue,
        ),
      ),

      // Input decoration styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Icon button styling
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: primaryBlue),
      ),

      // Slider styling
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryBlue,
        thumbColor: primaryBlue,
        overlayColor: Color(0x292196F3), // primaryBlue with alpha
      ),

      // Dialog styling
      dialogTheme: const DialogThemeData(
        backgroundColor: mediumGrey,
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
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: secondaryBlue,
        tertiary: accentOrange,
        error: errorRed,
        surface: mediumGrey,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: mediumGrey, foregroundColor: Colors.white),
      cardColor: mediumGrey,
      dialogTheme: const DialogThemeData(backgroundColor: mediumGrey),
      // Additional dark theme customizations can be added here
    );
  }
}
