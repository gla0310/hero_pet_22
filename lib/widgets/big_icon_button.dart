import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A large icon button suited to a tablet screen - used on the home screen
class BigIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// When provided, a small "+" icon appears in the card's corner to open a quick action
  /// (example: going directly to add an appointment without going through the menu first)
  final VoidCallback? onQuickAdd;
  final String? quickAddTooltip;

  const BigIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.onQuickAdd,
    this.quickAddTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = color ?? AppColors.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      shadowColor: Colors.black12,
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: baseColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 42, color: baseColor),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onQuickAdd != null)
            Positioned(
              top: 6,
              left: 6,
              child: Material(
                color: baseColor,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onQuickAdd,
                  child: Tooltip(
                    message: quickAddTooltip ?? 'Quick add',
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.add, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
