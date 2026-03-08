import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// Theme data factory for WINR UI components.
/// 
/// Creates Material Design theme data that matches the WINR branding
/// for consistent styling across all SDK components.
class WINRTheme {
  /// Creates a Material Design theme from WINR branding.
  static ThemeData create(WINRBranding branding) {
    return ThemeData(
      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: branding.primaryButtonColor,
        onPrimary: branding.primaryButtonTextColor,
        secondary: branding.accentGlowColor,
        onSecondary: branding.primaryColor,
        surface: branding.cardBackgroundColor,
        onSurface: branding.primaryColor,
        background: branding.backgroundColor,
        onBackground: branding.primaryColor,
        error: const Color(0xFFFF6B6B),
        onError: Colors.white,
        outline: branding.cardBorderColor,
      ),
      
      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: branding.backgroundColor,
        foregroundColor: branding.primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: branding.primaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: branding.primaryColor,
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: branding.cardBackgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(branding.cornerRadius),
          side: BorderSide(
            color: branding.cardBorderColor,
            width: 1,
          ),
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: branding.primaryButtonColor,
          foregroundColor: branding.primaryButtonTextColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(branding.cornerRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: branding.secondaryButtonColor,
          foregroundColor: branding.secondaryButtonTextColor,
          side: BorderSide(
            color: branding.cardBorderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(branding.cornerRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: branding.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(branding.cornerRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: branding.inputFieldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(branding.cornerRadius),
          borderSide: BorderSide(
            color: branding.inputFieldBorderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(branding.cornerRadius),
          borderSide: BorderSide(
            color: branding.inputFieldBorderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(branding.cornerRadius),
          borderSide: BorderSide(
            color: branding.primaryButtonColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(branding.cornerRadius),
          borderSide: const BorderSide(
            color: Color(0xFFFF6B6B),
          ),
        ),
        hintStyle: TextStyle(
          color: branding.inputFieldPlaceholderColor,
        ),
        labelStyle: TextStyle(
          color: branding.secondaryTextColor,
        ),
      ),
      
      // Text theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: branding.primaryColor,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          color: branding.primaryColor,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          color: branding.primaryColor,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        headlineLarge: TextStyle(
          color: branding.primaryColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          color: branding.primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          color: branding.primaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        titleLarge: TextStyle(
          color: branding.primaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          color: branding.secondaryTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          color: branding.secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          color: branding.primaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: branding.secondaryTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: branding.mutedTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          color: branding.primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          color: branding.secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          color: branding.mutedTextColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
      
      // Icon theme
      iconTheme: IconThemeData(
        color: branding.primaryColor,
        size: 24,
      ),
      
      // Scaffold background
      scaffoldBackgroundColor: branding.backgroundColor,
      
      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: branding.cardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(branding.cornerRadius),
            topRight: Radius.circular(branding.cornerRadius),
          ),
        ),
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: branding.cardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(branding.cornerRadius),
        ),
        titleTextStyle: TextStyle(
          color: branding.primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: branding.secondaryTextColor,
          fontSize: 14,
        ),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: branding.primaryButtonColor,
        linearTrackColor: branding.cardBorderColor,
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: branding.cardBorderColor,
        thickness: 1,
      ),
    );
  }
  
  /// Creates gradient background decoration.
  static BoxDecoration createGradientBackground(WINRBranding branding) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          branding.backgroundColor,
          branding.backgroundColor.withOpacity(0.8),
          branding.cardBackgroundColor.withOpacity(0.9),
        ],
      ),
    );
  }
  
  /// Creates glow effect for accent elements.
  static BoxShadow createGlowEffect(WINRBranding branding) {
    return BoxShadow(
      color: branding.accentGlowColor.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 2,
    );
  }
  
  /// Creates card decoration with border and optional glow.
  static BoxDecoration createCardDecoration(
    WINRBranding branding, {
    bool withGlow = false,
  }) {
    return BoxDecoration(
      color: branding.cardBackgroundColor,
      borderRadius: BorderRadius.circular(branding.cornerRadius),
      border: Border.all(
        color: branding.cardBorderColor,
      ),
      boxShadow: withGlow
          ? [createGlowEffect(branding)]
          : null,
    );
  }
}