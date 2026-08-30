import 'package:flutter/material.dart';

/// Official colors for the Hero Pet app
/// Primary color: a deep green suited to a professional veterinary clinic
class AppColors {
  AppColors._();

  static const Color primaryDark = Color(0xFF0B3D2E); // Very dark green
  static const Color primary = Color(0xFF14532D); // Primary dark green
  static const Color primaryLight = Color(0xFF1E7A4C); // Medium green
  static const Color accent = Color(0xFFD4AF37); // Gold for accents (optional)

  static const Color background = Color(0xFFF4F7F5);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1B1B1B);
  static const Color textLight = Color(0xFF6B6B6B);

  static const Color danger = Color(0xFFB3261E);
  static const Color warning = Color(0xFFB8860B);
  static const Color success = Color(0xFF1E7A4C);

  // Pet status colors
  static const Color statusInHotel = Color(0xFF1E7A4C);
  static const Color statusCheckedOut = Color(0xFF6B6B6B);
  static const Color statusInClinic = Color(0xFF8A5A00);
  static const Color statusDelivered = Color(0xFF6B6B6B);
}
