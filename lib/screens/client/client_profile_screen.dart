import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../../widgets/info_card.dart';
import '../pet/add_pet_screen.dart';
import '../pet/pet_profile_screen.dart';
import '../clinic/add_visit_screen.dart';
import '../appointments/add_appointment_screen.dart';
import '../hotel/add_admission_screen.dart';
import '../balance/balance_screen.dart';
import '../forms/form_submission_view_screen.dart';
import 'edit_client_screen.dart';

/// تعرض بيانات العميل الكاملة: معلوماته + كل أليفاته + أزرار إجراءات سريعة
class ClientProfileScreen extends StatefulWidget {
  final Client client;
  final List<Map<String, dynamic>> petsWithDetails;

  const ClientProfileScreen({super.key, required this.client, required this.petsWithDetails});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  late Client _client;
  late List<Map<String, dynamic>> _petsWithDetails;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _petsWithDetails = widget.petsWithDetails;
  }

  List<Pet> get _pets => _petsWithDetails.map((e) => e['pet'] as Pet).toList();

  /// يعيد جلب بيانات العميل وأليفاته من قاعدة البيانات بعد أي تعديل/أرشفة
  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final profile = await DBHelper.instance.getClientFullProfile(_client.phone);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (profile != null) {
        _client = profile['client'];
        _petsWithDetails = List<Map<String, dynamic>>.from(profile['pets']);
      }
    });
  }

  /// يظهر مربع اختيار الأليفة إن كان للعميل أكثر من أليفة واحدة، وإلا يختار
  /// الأليفة الوحيدة مباشرة، أو ينبّه إن لم يكن للعميل أي أليفة بعد.
  Future<Pet?> _pickPet(BuildContext context) async {
    final pets = _pets;
    if (pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة أليفة لهذا العميل أولاً')),
      );
      return null;
    }
    if (pets.length == 1) return pets.first;

    return showModalBottomSheet<Pet>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر الأليفة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...pets.map(
              (p) => ListTile(
                leading: const Icon(Icons.pets),
                title: Text(p.name),
                subtitle: Text(p.type),
                onTap: () => Navigator.pop(ctx, p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddVisit(BuildContext context) async {
    final pet = await _pickPet(context);
    if (pet == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddVisitScreen(petId: pet.id!, petName: pet.name)),
    );
    if (mounted) _refresh();
  }

  Future<void> _quickAddAppointment(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAppointmentScreen(prefilledPhone: _client.phone)),
    );
    if (mounted) _refresh();
  }

  Future<void> _quickCheckin(BuildContext context) async {
    final pet = await _pickPet(context);
    if (pet == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAdmissionScreen(petId: pet.id!, petName: pet.name, initialKind: AdmissionKind.hotelNormal),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _editClient() async {
    final updated = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => EditClientScreen(client: _client)),
    );
    if (updated != null && mounted) setState(() => _client = updated);
  }

  Future<void> _archiveClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أرشفة العميل'),
        content: Text('سيختفي "${_client.name}" من القوائم الرئيسية، وتبقى كل بياناته وسجلاته محفوظة ويمكن استعادته من الأرشيف. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (confirm != true || _client.id == null) return;

    await DBHelper.instance.archiveClient(_client.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم أرشفة العميل')));
    Navigator.pop(context);
  }

  Future<void> _archivePet(Pet pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أرشفة الأليفة'),
        content: Text('ستختفي "${pet.name}" من ملف العميل، وتبقى كل سجلاتها الطبية محفوظة ويمكن استعادتها من الأرشيف. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (confirm != true || pet.id == null) return;

    await DBHelper.instance.archivePet(pet.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم أرشفة الأليفة')));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return Scaffold(
      appBar: AppBar(
        title: Text('ملف العميل: ${client.name}'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: 'تعديل بيانات العميل', onPressed: _editClient),
          IconButton(icon: const Icon(Icons.archive_outlined), tooltip: 'أرشفة العميل', onPressed: _archiveClient),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_refreshing) const LinearProgressIndicator(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow(label: 'الاسم', value: client.name),
                    InfoRow(label: 'الجوال', value: client.phone),
                    if (client.civilId != null && client.civilId!.isNotEmpty)
                      InfoRow(label: 'السجل المدني', value: client.civilId!),
                    if (client.notes != null && client.notes!.isNotEmpty)
                      InfoRow(label: 'ملاحظات', value: client.notes!),
                    if (client.balance != 0)
                      InfoRow(
                        label: 'الرصيد',
                        value: client.balance == client.balance.roundToDouble()
                            ? client.balance.toStringAsFixed(0)
                            : client.balance.toStringAsFixed(2),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('إجراءات سريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickActionButton(
                  icon: Icons.pets,
                  label: 'إضافة أليفة',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddPetScreen(clientId: client.id!, clientName: client.name)),
                    );
                    if (mounted) _refresh();
                  },
                ),
                _QuickActionButton(
                  icon: Icons.local_hospital,
                  label: 'إضافة زيارة عيادة',
                  onTap: () => _quickAddVisit(context),
                ),
                _QuickActionButton(
                  icon: Icons.event_available,
                  label: 'إضافة موعد',
                  onTap: () => _quickAddAppointment(context),
                ),
                _QuickActionButton(
                  icon: Icons.hotel,
                  label: 'تسجيل دخول فندقة',
                  onTap: () => _quickCheckin(context),
                ),
                _QuickActionButton(
                  icon: Icons.account_balance_wallet,
                  label: 'تعديل الرصيد',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BalanceScreen(prefilledPhone: client.phone)),
                    );
                    if (mounted) _refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('الأليفات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            if (_petsWithDetails.isEmpty) const Text('لا يوجد أليفات مسجلة لهذا العميل بعد'),
            ..._petsWithDetails.map((entry) {
              final Pet pet = entry['pet'];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(child: Icon(Icons.pets)),
                  title: Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${pet.type} ${pet.breed != null ? "— ${pet.breed}" : ""}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: pet.status),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'archive') _archivePet(pet);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'archive', child: Text('أرشفة الأليفة')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PetProfileScreen(
                          pet: pet,
                          clientName: client.name,
                          visits: entry['visits'],
                          appointments: entry['appointments'],
                          admissions: entry['admissions'],
                          notesByAdmission: entry['notesByAdmission'] ?? const {},
                        ),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                ),
              );
            }),
            const SizedBox(height: 20),
            const Text('الاستمارات الإلكترونية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DBHelper.instance.getFormSubmissionsForClient(client.id!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final submissions = snapshot.data!;
                if (submissions.isEmpty) return const Text('لا يوجد استمارات محفوظة لهذا العميل بعد');
                return Column(
                  children: submissions.map((s) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                        title: Text(s['template_name']),
                        subtitle: Text(s['submitted_at']),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FormSubmissionViewScreen(submission: s)),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 14)),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
