import 'package:flutter/material.dart';

// Este es el archivo centralizado para el sistema de diseño de tu aplicación.
// Combina tu paleta de colores y estilos con una estructura organizada y escalable.
// Colócalo en: lib/config/theme/app_theme.dart

// -------------------------------------------
// PALETA DE COLORES
// -------------------------------------------
// Paleta de colores unificada para los temas claro y oscuro.
class AppColors {
  // --- Tema Claro "Classic Blue" ---
  static const Color lightPrimary = Color(0xFF0066FF); // Azul para confianza y profesionalismo
  static const Color lightAccent = Color(0xFF00B5E2);   // Cian para innovación y claridad
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF212529);

  // --- Tema Oscuro "Cyber Glow" ---
  static const Color darkPrimary = Color(0xFF0052FF);
  static const Color darkAccent = Color(0xFF00E0FF);
  static const Color darkBackground = Color(0xFF1A1C20);
  static const Color darkSurface = Color(0xFF24262B);
  static const Color darkText = Color(0xFFF8F9FA);
  
  // --- Colores Semánticos (Consistentes en ambos temas) ---
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFDC3545);
}

// -------------------------------------------
// TIPOGRAFÍA
// -------------------------------------------
// Usando 'Lato' como la fuente principal de la app.
class AppTextStyles {
  static const String _fontFamily = 'Lato';

  // Define los estilos de texto para ser reutilizados.
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.normal),
    bodyMedium: TextStyle(fontFamily: _fontFamily, fontSize: 15, height: 1.5),
    labelLarge: TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );

  // Tema de texto para el modo CLARO
  static TextTheme get lightTextTheme => _textTheme.apply(
        bodyColor: AppColors.lightText,
        displayColor: AppColors.lightText,
      );

  // Tema de texto para el modo OSCURO
  static TextTheme get darkTextTheme => _textTheme.apply(
        bodyColor: AppColors.darkText,
        displayColor: AppColors.darkText,
      );
}

// -------------------------------------------
// ESPACIADO Y DECORACIONES
// -------------------------------------------
class AppDecorations {
    // Espaciado
    static const double spacingSm = 8.0;
    static const double spacingMd = 16.0;
    static const double spacingLg = 24.0;

    // Radios de Borde
    static final BorderRadius buttonRadius = BorderRadius.circular(30.0);
    static final BorderRadius cardRadius = BorderRadius.circular(16.0);
    static final BorderRadius inputRadius = BorderRadius.circular(12.0);
}


// -------------------------------------------
// TEMA GENERAL DE LA APLICACIÓN
// -------------------------------------------
class AppTheme {

  // --- TEMA CLARO "CLASSIC BLUE" ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTextStyles._fontFamily,
      scaffoldBackgroundColor: AppColors.lightBackground,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.lightPrimary,
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightAccent,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: AppColors.danger,
      ),

      textTheme: AppTextStyles.lightTextTheme,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: AppDecorations.spacingLg, vertical: 14),
          textStyle: AppTextStyles.lightTextTheme.labelLarge
        ),
      ),

      cardTheme: CardThemeData( // <-- CORRECCIÓN AQUÍ
        elevation: 2,
        color: AppColors.lightSurface,
        shadowColor: Colors.black.withAlpha(25),
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.cardRadius,
          side: BorderSide(color: Colors.grey.shade200, width: 1)
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: AppDecorations.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDecorations.inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDecorations.inputRadius,
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
        ),
      ),
    );
  }

  // --- TEMA OSCURO "CYBER GLOW" ---
  static ThemeData get darkTheme {
     return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTextStyles._fontFamily,
      scaffoldBackgroundColor: AppColors.darkBackground,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkAccent,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        error: AppColors.danger,
      ),

      textTheme: AppTextStyles.darkTextTheme,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: AppDecorations.spacingLg, vertical: 14),
          textStyle: AppTextStyles.darkTextTheme.labelLarge
        ),
      ),

      cardTheme: CardThemeData( // <-- CORRECCIÓN AQUÍ
        elevation: 0,
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: AppDecorations.cardRadius),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: AppDecorations.inputRadius,
          borderSide: BorderSide.none,
        ),
         focusedBorder: OutlineInputBorder(
          borderRadius: AppDecorations.inputRadius,
          borderSide: const BorderSide(color: AppColors.darkAccent, width: 2),
        ),
      ),
    );
  }
}
