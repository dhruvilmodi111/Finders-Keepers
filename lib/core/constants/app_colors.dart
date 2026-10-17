import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary: Teal Palette
  static const Color primaryTeal = Color(0xFF00897B); // Teal 600
  static const Color primaryTealDark = Color(0xFF005B4F);
  static const Color primaryTealLight = Color(0xFF4EBaaa);
  static const Color primaryTealContainer = Color(0xFFB2DFDB); // Teal 100
  static const Color onPrimaryTealContainer = Color(0xFF00201A);

  // Secondary / Accent: Amber Palette
  static const Color accentAmber = Color(0xFFFFB300); // Amber 600
  static const Color accentAmberDark = Color(0xFFC68400);
  static const Color accentAmberLight = Color(0xFFFFE54C);
  static const Color accentAmberContainer = Color(0xFFFFECB3); // Amber 100
  static const Color onAccentAmberContainer = Color(0xFF261900);

  // Status Colors
  static const Color statusLost = Color(0xFFE53935); // Red 600
  static const Color statusFound = Color(0xFF43A047); // Green 600
  static const Color statusClaimed = Color(0xFFFB8C00); // Orange 600
  static const Color statusReturned = Color(0xFF1E88E5); // Blue 600

  // Light Theme Neutrals
  static const Color lightBackground = Color(0xFFF8FAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEFF3F2);
  static const Color lightTextPrimary = Color(0xFF191C1B);
  static const Color lightTextSecondary = Color(0xFF6F7977);
  static const Color lightBorder = Color(0xFFE0E5E3);

  // Dark Theme Neutrals
  static const Color darkBackground = Color(0xFF111413);
  static const Color darkSurface = Color(0xFF191C1B);
  static const Color darkSurfaceVariant = Color(0xFF232826);
  static const Color darkTextPrimary = Color(0xFFE1E3E2);
  static const Color darkTextSecondary = Color(0xFF899390);
  static const Color darkBorder = Color(0xFF2E3331);
}
