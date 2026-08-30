import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/admission.dart';
import '../../utils/date_helper.dart';
import '../../utils/whatsapp_helper.dart';
import '../../utils/send_to_client_prompt.dart';
import 'admission_notes_screen.dart';

/// تعرض جميع الأليفات الموجودة حالياً سواء فندقة عادية/علاجية أو إجراء طبي
class CurrentGuestsScreen extends StatefulWidget {
  const CurrentGuestsScreen({super.key});

  @override
  State<CurrentGuestsScreen> createState() => _CurrentGuestsScreenState();
}

class _CurrentGuestsScreenState extends State<CurrentGuestsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = DBHelper.instance.getCurrentlyPresentWithDetails();
  }

  String _kindLabel(Map<String, dynamic> item) {
    if (item['type'] == AdmissionType.procedure) return AdmissionKind.procedure;
    return item['boarding_type'] ?? '-';
  }

  Color _kindColor(Map<String, dynamic> item) {
    return item['type'] == AdmissionType.procedure ? AppColors.statusInClinic : AppColors.statusInHotel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المتواجدون حالياً')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('لا يوجد أليفات موجودة حالياً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final color = _kindColor(item);
              final daysLate = DateHelper.daysLate(item['expected_exit_date']);
              final isOverdue = daysLate > 0;
              // خانة الإرسال تظهر فقط لأنواع الفندقة (عادية/علاجية) - وليس
              // الإجراء الطبي - وفقط عندما يكون موعد الخروج المتوقع اليوم
              final isHotelType = item['type'] != AdmissionType.procedure;
              final isDueToday = (item['expected_exit_date'] as String?)?.split(' ').first == DateHelper.today();
              final showSendButton = isHotelType && isDueToday;

              return Card(
                color: isOverdue ? AppColors.danger.withOpacity(0.06) : null,
                shape: isOverdue
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.danger.withOpacity(0.5), width: 1.4),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.fromLTRB(14, 14, 14, showSendButton ? 0 : 14),
                      leading: Icon(Icons.pets, color: isOverdue ? AppColors.danger : color, size: 32),
                      title: Text(item['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('العميل: ${item['client_name']} — ${item['client_phone']}'),
                          Text('نوع الحالة: ${_kindLabel(item)}'),
                          Text('تاريخ الدخول: ${item['entry_date']}'),
                          Text('الخروج المتوقع: ${DateHelper.displayDate(item['expected_exit_date'])}'),
                          if (isOverdue)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'متأخر عن الخروج — $daysLate يوم',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.notes),
                      onTap: () async {
                        final admission = Admission.fromMap(item);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdmissionNotesScreen(admission: admission, petName: item['pet_name']),
                          ),
                        );
                        setState(_reload);
                      },
                    ),
                    // صف مستقل بمساحته الخاصة لزر "إرسال" - بجانب الأليف لكن
                    // خارج منطقة trailing الضيقة، وبدون أي علاقة بتسجيل الخروج
                    if (showSendButton)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text('إرسال'),
                            onPressed: () {
                              final message = WhatsAppHelper.buildHotelCheckoutTodayMessage(
                                petName: item['pet_name'],
                                gender: item['pet_gender'],
                              );
                              SendToClientPrompt.show(context: context, phone: item['client_phone'], message: message);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
