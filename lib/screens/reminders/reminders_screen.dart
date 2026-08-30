import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../utils/whatsapp_helper.dart';
import '../../utils/date_helper.dart';

/// Reminders screen - divided into three sections:
/// 1) Upcoming appointments (follow-up / vaccination / grooming / other)
/// 2) Today's checkouts (standard/medical boarding or a medical procedure due for checkout today)
/// 3) Overdue checkouts
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late Future<List<Map<String, dynamic>>> _appointmentsFuture;
  late Future<List<Map<String, dynamic>>> _deliveriesFuture;
  late Future<List<Map<String, dynamic>>> _overdueFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _appointmentsFuture = DBHelper.instance.getUpcomingAppointmentsWithDetails();
    _deliveriesFuture = DBHelper.instance.getAdmissionsDueTodayWithDetails();
    _overdueFuture = DBHelper.instance.getOverdueAdmissionsWithDetails();
  }

  String _kindLabel(Map<String, dynamic> item) {
    if (item['type'] == AdmissionType.procedure) return AdmissionKind.procedure;
    return item['boarding_type'] ?? '-';
  }

  Future<void> _sendWhatsApp({required String phone, required String message}) async {
    final result = await WhatsAppHelper.openWhatsAppWithMessage(phone: phone, message: message);
    if (!mounted) return;
    if (result == WhatsAppOpenResult.notInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp on this device. You can copy the message and send it manually.')),
      );
    }
  }

  Future<void> _copyMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
  }

  Widget _whatsAppActions({required String phone, required String message, required Color color}) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.chat),
            label: const Text('Send via WhatsApp'),
            onPressed: () => _sendWhatsApp(phone: phone, message: message),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          width: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => _copyMessage(message),
            child: const Icon(Icons.copy, size: 20),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reminders'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Upcoming Appointments'),
              Tab(text: 'Today\'s Checkouts'),
              Tab(text: 'Overdue Checkouts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAppointmentsTab(),
            _buildDeliveriesTab(),
            _buildOverdueTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _appointmentsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No upcoming appointments'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final a = items[i];
            final reason = a['reason'] as String?;
            final weekday = DateHelper.arabicWeekday(a['date']);

            String? message;
            if (reason == AppointmentType.followUp) {
              message = WhatsAppHelper.buildFollowUpAppointmentMessage(
                petName: a['pet_name'],
                weekday: weekday,
                date: a['date'],
                notes: a['notes'],
              );
            } else if (reason == AppointmentType.vaccination) {
              message = WhatsAppHelper.buildVaccinationAppointmentMessage(
                petName: a['pet_name'],
                weekday: weekday,
                date: a['date'],
                notes: a['notes'],
              );
            }
            // Free grooming and other reasons (medical procedure/other): no WhatsApp
            // message is sent to the client - only an in-app alert for staff is shown
            final isGrooming = reason == AppointmentType.grooming;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Client: ${a['client_name']}'),
                    Text('Appointment Type: ${reason ?? '-'}'),
                    Text('Date: ${a['date']} — Time: ${a['time']}'),
                    const SizedBox(height: 10),
                    if (message != null)
                      _whatsAppActions(phone: a['client_phone'], message: message, color: AppColors.success)
                    else if (isGrooming)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Free grooming — no message sent to the client, this is an internal alert only',
                          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    else
                      const Text('No WhatsApp message template for this type', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveriesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _deliveriesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No checkouts due today'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final kind = _kindLabel(item);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Client: ${item['client_name']} — ${item['client_phone']}'),
                    Text('Case Type: $kind'),
                    const Text('Expected Checkout Time: Today'),
                    const SizedBox(height: 10),
                    Builder(builder: (context) {
                      final message = WhatsAppHelper.buildCheckoutDueMessage(
                        petName: item['pet_name'],
                        gender: item['pet_gender'],
                        kind: kind,
                      );
                      return _whatsAppActions(phone: item['client_phone'], message: message, color: AppColors.warning);
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverdueTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _overdueFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No overdue checkouts'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final daysLate = DateHelper.daysLate(item['expected_exit_date']);
            return Card(
              color: AppColors.danger.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.danger.withOpacity(0.5), width: 1.4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20)),
                          child: const Text('Overdue for Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Client: ${item['client_name']} — ${item['client_phone']}'),
                    Text('Case Type: ${_kindLabel(item)}'),
                    Text('Expected Checkout Date: ${DateHelper.displayDate(item['expected_exit_date'])}'),
                    Text('Days Overdue: $daysLate', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
