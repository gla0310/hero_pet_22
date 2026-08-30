import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/appointment.dart';
import '../clinic/add_visit_screen.dart';
import 'add_appointment_screen.dart';

/// Appointments screen: an "add appointment" button + a list of all upcoming
/// appointments, with the ability to open any appointment to edit or delete it.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = DBHelper.instance.getUpcomingAppointmentsWithDetails();
  }

  Future<void> _goToAddAppointment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
    );
    if (result == true) setState(_reload);
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppointmentStatus.attended:
        return AppColors.success;
      case AppointmentStatus.noShow:
        return AppColors.danger;
      case AppointmentStatus.cancelled:
        return AppColors.textLight;
      case AppointmentStatus.rescheduled:
        return AppColors.warning;
      default:
        return AppColors.primaryLight;
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> a, String status) async {
    final appointmentId = a['id'] as int;
    await DBHelper.instance.updateAppointmentStatus(appointmentId, status);
    if (!mounted) return;

    // When status is "attended" we automatically navigate to open a new clinic visit linked to the same appointment and pet
    if (status == AppointmentStatus.attended) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddVisitScreen(
            petId: a['pet_id'] as int,
            petName: a['pet_name'],
            appointmentId: appointmentId,
            appointmentReason: a['reason'] as String?,
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) setState(_reload);
      return;
    }

    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          // Extra "add appointment" button in the top bar to keep it always visible
          IconButton(
            tooltip: 'Add Appointment',
            icon: const Icon(Icons.add_circle, size: 28),
            onPressed: _goToAddAppointment,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddAppointment,
        icon: const Icon(Icons.add),
        label: const Text('Add Appointment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No upcoming appointments'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _goToAddAppointment,
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Appointment'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final status = (a['status'] as String?) ?? AppointmentStatus.pending;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event,
                      color: AppColors.primary, size: 32),
                  title: Text('${a['pet_name']} — ${a['reason'] ?? ''}'),
                  subtitle: Text(
                    'Client: ${a['client_name']} (${a['client_phone']})\n${a['date']} — ${a['time']}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    initialValue: status,
                    onSelected: (v) => _changeStatus(a, v),
                    itemBuilder: (context) => AppointmentStatus.all
                        .map((s) => PopupMenuItem(value: s, child: Text(s)))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor(status)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddAppointmentScreen(
                            existingAppointment: Appointment.fromMap(a)),
                      ),
                    );
                    if (result == true) setState(_reload);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
