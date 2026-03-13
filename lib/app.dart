import 'package:flutter/material.dart';
import 'helpers.dart';
import 'home_page.dart';
import 'models.dart';

class InternshipLogApp extends StatefulWidget {
  const InternshipLogApp({super.key});

  @override
  State<InternshipLogApp> createState() => _InternshipLogAppState();
}

class _InternshipLogAppState extends State<InternshipLogApp> {
  @override
  Widget build(BuildContext context) {
    // We'll handle settings in InternshipLogHomePage and pass them back up or use a provider/callback
    // For simplicity in this small app, we'll let the HomePage rebuild the app or use a Stream/ValueNotifier
    return const _InternshipLogAppContent();
  }
}

class _InternshipLogAppContent extends StatefulWidget {
  const _InternshipLogAppContent();

  @override
  State<_InternshipLogAppContent> createState() =>
      _InternshipLogAppContentState();
}

class _InternshipLogAppContentState extends State<_InternshipLogAppContent> {
  AppSettings _settings = const AppSettings();

  void _updateSettings(AppSettings settings) {
    setState(() {
      _settings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Log Magang Academic',
      themeMode: switch (_settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: InternshipLogHomePage(
        onSettingsChanged: _updateSettings,
        initialSettings: _settings,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final primaryColor = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
    final accentColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFDFCFB);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFF0F766E).withOpacity(0.08),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        elevation: 0,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final isSelected = states.contains(MaterialState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black45),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      textTheme: baseTheme.textTheme.copyWith(
        headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
          fontFamily: 'Serif',
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Serif',
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
          fontFamily: 'Serif',
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
        ),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
        bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
          height: 1.6,
          color: isDark ? Colors.white70 : const Color(0xFF334155),
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: isDark ? Colors.white60 : const Color(0xFF475569),
        ),
      ),
    );
  }
}
