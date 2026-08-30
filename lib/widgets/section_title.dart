import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const SectionTitle({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
