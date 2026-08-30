import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../widgets/info_card.dart';

class AllCheckinsScreen extends StatelessWidget {
  const AllCheckinsScreen({super.key});

  String _kindLabel(Map<String, dynamic> item) {
    if (item['type'] == AdmissionType.procedure) return AdmissionKind.procedure;
    return item['boarding_type'] ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Hotel Check-ins')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBHelper.instance.getRecentAdmissionCheckins(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('No check-ins yet'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.pets, color: AppColors.statusInHotel, size: 30),
                  title: Text(item['pet_name']),
                  subtitle: Text('${item['client_name']} — ${item['client_phone']}\n${_kindLabel(item)} — Check-in: ${item['entry_date']}'),
                  isThreeLine: true,
                  trailing: StatusBadge(status: item['status']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
