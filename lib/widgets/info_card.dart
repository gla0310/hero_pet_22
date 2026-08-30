import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textDark))),
        ],
      ),
    );
  }
}

/// شارة تعرض حالة الأليفة الحالية بلون مناسب
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _colorForStatus() {
    switch (status) {
      case 'موجودة في الفندقة':
        return AppColors.statusInHotel;
      case 'موجودة في العيادة':
        return AppColors.statusInClinic;
      case 'تم الخروج':
      case 'تم التسليم':
        return AppColors.statusCheckedOut;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
