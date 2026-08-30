import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/admission.dart';
import '../../utils/date_helper.dart';
import '../../utils/whatsapp_helper.dart';
import '../../utils/send_to_client_prompt.dart';
import 'hotel_checkout_screen.dart';

class CurrentHotelScreen extends StatefulWidget {
  const CurrentHotelScreen({super.key});

  @override
  State<CurrentHotelScreen> createState() => _CurrentHotelScreenState();
}

class _CurrentHotelScreenState extends State<CurrentHotelScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = DBHelper.instance.getCurrentlyInHotelWithDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المتواجدون حالياً في الفندقة')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('لا يوجد أليفات في الفندقة حالياً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final isDueToday = (item['expected_exit_date'] as String?)?.split(' ').first == DateHelper.today();
              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      leading: const Icon(Icons.pets, color: AppColors.statusInHotel, size: 32),
                      title: Text(item['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('العميل: ${item['client_name']} — ${item['client_phone']}'),
                          Text('نوع الفندقة: ${item['boarding_type'] ?? '-'}'),
                          Text('تاريخ الدخول: ${item['entry_date']}'),
                          Text('الخروج المتوقع: ${DateHelper.displayDate(item['expected_exit_date'])}'),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final admission = Admission.fromMap(item);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HotelCheckoutScreen(admission: admission, petName: item['pet_name']),
                            ),
                          );
                          if (result == true) setState(_reload);
                        },
                        child: const Text('تسجيل خروج'),
                      ),
                    ),
                    // زر "إرسال" له مساحته الخاصة أسفل البطاقة بدل ازدحامه مع
                    // زر "تسجيل خروج" داخل نفس الحيّز الضيق (trailing) - وهو
                    // ما كان يسبب اختفاءه بصرياً رغم أن الشرط كان يتحقق فعلياً
                    if (isDueToday)
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
                      )
                    else
                      const SizedBox(height: 14),
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
