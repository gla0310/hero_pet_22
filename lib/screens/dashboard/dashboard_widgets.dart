import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../utils/date_helper.dart';
import '../client/client_profile_screen.dart';
import '../pet/pet_profile_screen.dart';
import 'all_clients_screen.dart';
import 'all_checkins_screen.dart';
import 'all_deliveries_screen.dart';

/// Opens a specific pet's profile (by its ID) starting from its client's phone
/// number - used by the dashboard sections (recent check-ins/check-outs) to
/// open the same pet profile screen used throughout the rest of the app.
Future<void> _openPetProfile(BuildContext context, String clientPhone, int petId) async {
  final profile = await DBHelper.instance.getClientFullProfile(clientPhone);
  if (profile == null || !context.mounted) return;
  final pets = List<Map<String, dynamic>>.from(profile['pets']);
  final entry = pets.firstWhere(
    (e) => e['pet'].id == petId,
    orElse: () => <String, dynamic>{},
  );
  if (entry.isEmpty || !context.mounted) return;

  final client = profile['client'];
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PetProfileScreen(
        pet: entry['pet'],
        clientName: client.name,
        visits: entry['visits'],
        appointments: entry['appointments'],
        admissions: entry['admissions'],
        notesByAdmission: entry['notesByAdmission'] ?? const {},
      ),
    ),
  );
}

/// A generic section card used for each dashboard section
class DashboardSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onViewAll;
  final Widget child;

  const DashboardSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onViewAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View All')),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

/// "Recently added clients" section
class RecentClientsSection extends StatelessWidget {
  const RecentClientsSection({super.key});

  Future<void> _openClient(BuildContext context, String phone) async {
    final profile = await DBHelper.instance.getClientFullProfile(phone);
    if (profile == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProfileScreen(
          client: profile['client'],
          petsWithDetails: List<Map<String, dynamic>>.from(profile['pets']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Recently Added Clients',
      icon: Icons.person_add_alt_1,
      onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllClientsScreen())),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBHelper.instance.getRecentClientsWithPetCount(limit: 5),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Text('No clients yet');
          return Column(
            children: items.map((item) {
              final client = Client.fromMap(item);
              final petCount = item['pet_count'] ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(client.name),
                subtitle: Text('${client.phone} — ${DateHelper.displayDate(client.createdAt)} — Pets: $petCount'),
                onTap: () => _openClient(context, client.phone),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// "Recent hotel check-ins" section
class RecentCheckinsSection extends StatelessWidget {
  const RecentCheckinsSection({super.key});

  String _kindLabel(Map<String, dynamic> item) {
    if (item['type'] == AdmissionType.procedure) return AdmissionKind.procedure;
    return item['boarding_type'] ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Recent Hotel Check-ins',
      icon: Icons.login,
      onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCheckinsScreen())),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBHelper.instance.getRecentAdmissionCheckins(limit: 5),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Text('No check-ins yet');
          return Column(
            children: items.map((item) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pets, color: AppColors.statusInHotel),
                title: Text(item['pet_name']),
                subtitle: Text('${item['client_name']} — ${item['client_phone']}\n${_kindLabel(item)} — Check-in: ${item['entry_date']}'),
                isThreeLine: true,
                onTap: () => _openPetProfile(context, item['client_phone'], item['pet_id'] as int),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// "Recent hotel check-outs" section
class RecentDeliveriesSection extends StatelessWidget {
  const RecentDeliveriesSection({super.key});

  String _kindLabel(Map<String, dynamic> item) {
    if (item['type'] == AdmissionType.procedure) return AdmissionKind.procedure;
    return item['boarding_type'] ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Recent Hotel Check-outs',
      icon: Icons.logout,
      onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllDeliveriesScreen())),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBHelper.instance.getRecentDeliveries(limit: 5),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Text('No check-outs yet');
          return Column(
            children: items.map((item) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: AppColors.textLight),
                title: Text(item['pet_name']),
                subtitle: Text(
                  '${item['client_name']} — ${_kindLabel(item)}\nCheck-out: ${item['actual_exit_date'] ?? '-'} — Status: ${item['status']}',
                ),
                isThreeLine: true,
                onTap: () => _openPetProfile(context, item['client_phone'], item['pet_id'] as int),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Alert banner for overdue check-outs (shown at the top of the dashboard when overdue cases exist)
class OverdueBanner extends StatelessWidget {
  const OverdueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBHelper.instance.getOverdueAdmissionsWithDetails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final count = snapshot.data!.length;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'There are $count overdue check-outs — check "Currently Present"',
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
