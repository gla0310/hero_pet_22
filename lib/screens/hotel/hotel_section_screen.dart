import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'checkin_search_screen.dart';
import 'current_guests_screen.dart';
import 'checkout_search_screen.dart';

/// Entry point for the entire hotel section: check-in / currently present / checkout
class HotelSectionScreen extends StatelessWidget {
  const HotelSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _HotelCard(
              icon: Icons.login,
              title: 'Check-in',
              subtitle: 'Regular / treatment boarding or medical procedure',
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckinSearchScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _HotelCard(
              icon: Icons.meeting_room,
              title: 'Currently Present',
              subtitle: 'View and manage notes for every pet present',
              color: AppColors.statusInHotel,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CurrentGuestsScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _HotelCard(
              icon: Icons.logout,
              title: 'Checkout',
              subtitle: 'End a boarding stay or deliver after a medical procedure',
              color: AppColors.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutSearchScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HotelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 34, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textLight)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios, size: 16, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
