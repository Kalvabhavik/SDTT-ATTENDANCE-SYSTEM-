import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for the Attendrix mobile theme,
/// matching the reference design image:
/// - Vibrant sky-blue gradients
/// - Pure white rounded floating cards (24px radius)
/// - Four distinct pastel action squircles (Leave, Calendar, Salary/Courses, Task)
/// - Floating sky-blue bottom capsule dock
class AppThemeTokens {
  AppThemeTokens._();

  // ── Color Palette ──────────────────────────────────────────────────────────
  static const Color skyStart = Color(0xFF38BDF8);       // Sky Blue 400
  static const Color skyEnd = Color(0xFF0284C7);         // Sky Blue 600 / Royal
  static const Color canvasBg = Color(0xFFEBF3FA);       // Powder Blue Page Canvas
  static const Color surfaceWhite = Color(0xFFFFFFFF);   // Pure White Card
  static const Color surfaceSubtle = Color(0xFFF8FAFC);  // Soft Gray Slate 50

  // ── Typography Colors ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);    // Dark Charcoal / Slate 900
  static const Color textSecondary = Color(0xFF64748B);  // Slate 500
  static const Color textTertiary = Color(0xFF94A3B8);   // Slate 400
  static const Color textInverse = Color(0xFFFFFFFF);    // Pure White on Gradients

  // ── 4 Quick-Action Squircle Colors ─────────────────────────────────────────
  static const Color actionLeave = Color(0xFFFF6584);    // Watermelon Coral Pink
  static const Color actionCalendar = Color(0xFF38BDF8); // Sky Blue
  static const Color actionCourses = Color(0xFF2ED573);  // Mint Emerald
  static const Color actionTask = Color(0xFF9B51E0);     // Lavender Purple

  // ── Status Indicators ──────────────────────────────────────────────────────
  static const Color statusSuccess = Color(0xFF10B981);  // Verified / Present (Emerald)
  static const Color statusWarning = Color(0xFFF59E0B);  // In Review / Flagged (Amber)
  static const Color statusDanger = Color(0xFFEF4444);   // Absent / Rejected (Rose)
  static const Color statusInfo = Color(0xFF0284C7);     // Information / Scheduled (Blue)

  // ── Navigation Dock ────────────────────────────────────────────────────────
  static const Color dockBackground = Color(0xFF38BDF8); // Translucent sky dock
  static const Color dockPillActive = Color(0xFFFFFFFF); // White active tab pill
  static const Color dockIconActive = Color(0xFF0284C7); // Active icon color
  static const Color dockIconInactive = Color(0xFFFFFFFF);// Inactive white icon

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [skyStart, skyEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient calendarHeaderGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient characterGlowGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Corner Radii ───────────────────────────────────────────────────────────
  static const double radiusCard = 24.0;
  static const double radiusSquircle = 18.0;
  static const double radiusDock = 28.0;
  static const double radiusPill = 20.0;
  static const double radiusTile = 14.0;

  static const BorderRadius borderCard = BorderRadius.all(Radius.circular(radiusCard));
  static const BorderRadius borderSquircle = BorderRadius.all(Radius.circular(radiusSquircle));
  static const BorderRadius borderDock = BorderRadius.all(Radius.circular(radiusDock));
  static const BorderRadius borderPill = BorderRadius.all(Radius.circular(radiusPill));
  static const BorderRadius borderTile = BorderRadius.all(Radius.circular(radiusTile));

  // ── Shadows ────────────────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1F0284C7), // ~12% opacity
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000), // ~4% opacity
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> dockShadow = [
    BoxShadow(
      color: Color(0x400284C7), // ~25% opacity
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> tileShadow = [
    BoxShadow(
      color: Color(0x140284C7),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  // ── Typography Styles ──────────────────────────────────────────────────────
  static TextStyle heroGreeting({Color color = textInverse}) => GoogleFonts.plusJakartaSans(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: -0.5,
  );

  static TextStyle screenTitle({Color color = textPrimary}) => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle cardTitle({Color color = textPrimary}) => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle bodyBold({Color color = textPrimary, double size = 13.5}) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle bodyMedium({Color color = textSecondary, double size = 12.5}) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle caption({Color color = textTertiary, double size = 11.0}) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

/// Global theme definition applied to MaterialApp
ThemeData buildAttendrixTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppThemeTokens.canvasBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppThemeTokens.skyEnd,
      primary: AppThemeTokens.skyEnd,
      secondary: AppThemeTokens.actionCourses,
      surface: AppThemeTokens.surfaceWhite,
      error: AppThemeTokens.statusDanger,
      brightness: Brightness.light,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    cardTheme: CardThemeData(
      color: AppThemeTokens.surfaceWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppThemeTokens.borderCard),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppThemeTokens.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppThemeTokens.skyEnd,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
