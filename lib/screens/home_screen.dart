import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../database/db_helper.dart';
import '../models/client.dart';
import '../widgets/big_icon_button.dart';
import 'client/add_client_screen.dart';
import 'client/client_profile_screen.dart';
import 'appointments/appointments_screen.dart';
import 'appointments/add_appointment_screen.dart';
import 'hotel/hotel_section_screen.dart';
import 'balance/balance_screen.dart';
import 'reminders/reminders_screen.dart';
import 'backup/backup_screen.dart';
import 'vaccination/vaccination_packages_screen.dart';
import 'grooming/grooming_screen.dart';
import 'dashboard/dashboard_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  Future<void> _openClientProfile(Client client) async {
    final profile = await DBHelper.instance.getClientFullProfile(client.phone);
    if (profile == null || !mounted) return;
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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _searching = true);
    final results = await DBHelper.instance.searchClientsByPhone(query);
    setState(() => _searching = false);

    if (!mounted) return;

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد عملاء مطابقين لبحثك')),
      );
      return;
    }

    // نتيجة واحدة فقط: افتح ملفه مباشرة دون خطوة اختيار إضافية
    if (results.length == 1) {
      await _openClientProfile(results.first);
      return;
    }

    // أكثر من نتيجة: اعرضها للموظف ليختار العميل الصحيح
    final chosen = await showModalBottomSheet<Client>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر العميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: results
                    .map(
                      (c) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen != null) await _openClientProfile(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ListView(
            children: [
              // الشريط العلوي: جرس التذكيرات على اليسار + شريط بحث طويل في المنتصف
              Row(
                children: [
                  IconButton(
                    tooltip: 'التذكيرات والمواعيد القادمة',
                    icon: const Icon(Icons.notifications, color: AppColors.primary, size: 30),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RemindersScreen()),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: 'ابحث برقم الجوال أو اسم العميل...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: _search,
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'النسخ الاحتياطي',
                    icon: const Icon(Icons.settings_backup_restore, color: AppColors.textLight),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.pets, color: AppColors.primary, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'hero pet',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // الأيقونات الرئيسية
              Row(
                children: [
                  Expanded(
                    child: BigIconButton(
                      icon: Icons.person_add_alt_1,
                      label: 'إضافة عميل',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddClientScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: BigIconButton(
                      icon: Icons.event_available,
                      label: 'المواعيد',
                      color: AppColors.primaryLight,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
                      ),
                      quickAddTooltip: 'إضافة موعد',
                      onQuickAdd: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BigIconButton(
                      icon: Icons.hotel,
                      label: 'الفندقة',
                      color: AppColors.statusInHotel,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HotelSectionScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: BigIconButton(
                      icon: Icons.account_balance_wallet,
                      label: 'رصيد',
                      color: AppColors.warning,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BalanceScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BigIconButton(
                      icon: Icons.vaccines,
                      label: 'باقات التطعيمات',
                      color: AppColors.primaryDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VaccinationPackagesScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: BigIconButton(
                      icon: Icons.content_cut,
                      label: 'الشاور والحلاقة',
                      color: AppColors.accent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroomingScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // لوحة المعلومات (Dashboard) - جزء من نفس القائمة القابلة للتمرير
              // حتى تختفي الأيقونات عند التمرير لأسفل ويظهر المزيد من المحتوى
              const OverdueBanner(),
              const RecentCheckinsSection(),
              const SizedBox(height: 14),
              const RecentDeliveriesSection(),
              const SizedBox(height: 14),
              const RecentClientsSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
