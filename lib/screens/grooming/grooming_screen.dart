import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../../models/grooming_service.dart';
import '../../utils/date_helper.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/whatsapp_helper.dart';
import '../../utils/send_to_client_prompt.dart';
import '../client/add_client_screen.dart';
import '../pet/add_pet_screen.dart';

enum _Step { client, pet, services }

/// شاشة قسم الشاور والحلاقة: تفتح مباشرة على قائمة كل خدمات اليوم (مع شريط
/// بحث فوقها لإضافة عميل/أليفة جديدة إن جاء أحد)، ثم اختيار الأليفة (بصورتها)
/// ← اختيار الخدمات، مع عرض عداد الشاور والشاور المجاني المستحق إن وُجد.
///
/// إذا مُرِّر [initialPetId] (مثلاً من شاشة "تم حفظ الأليفة" مباشرة بعد
/// إضافتها)، تُفتح الشاشة مباشرة على خطوة اختيار الخدمات لهذه الأليفة.
class GroomingScreen extends StatefulWidget {
  final int? initialPetId;

  const GroomingScreen({super.key, this.initialPetId});

  @override
  State<GroomingScreen> createState() => _GroomingScreenState();
}

class _GroomingScreenState extends State<GroomingScreen> {
  _Step _step = _Step.client;
  bool _loadingInitialPet = false;

  // خطوة 1: العميل + قائمة خدمات اليوم
  final _searchController = TextEditingController();
  List<Client> _searchResults = [];
  bool _searching = false;
  bool _searched = false;
  Client? _selectedClient;
  late Future<List<Map<String, dynamic>>> _todayServicesFuture;

  // خطوة 2: الأليفة
  List<Pet> _pets = [];
  Pet? _selectedPet;

  // خطوة 3: الخدمات
  final Set<String> _selectedServices = {};
  Map<String, dynamic>? _showerProgress;
  bool _useFreeShower = false;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reloadTodayServices();
    if (widget.initialPetId != null) {
      _loadInitialPet(widget.initialPetId!);
    }
  }

  void _reloadTodayServices() {
    _todayServicesFuture = DBHelper.instance.getTodayGroomingServicesWithDetails();
  }

  Future<void> _loadInitialPet(int petId) async {
    setState(() => _loadingInitialPet = true);
    final pet = await DBHelper.instance.getPetById(petId);
    if (pet == null) {
      if (mounted) setState(() => _loadingInitialPet = false);
      return;
    }
    final client = await DBHelper.instance.getClientById(pet.clientId);
    if (!mounted || client == null) {
      if (mounted) setState(() => _loadingInitialPet = false);
      return;
    }
    final pets = await DBHelper.instance.getPetsByClientId(client.id!);
    if (!mounted) return;
    setState(() {
      _selectedClient = client;
      _pets = pets;
      _loadingInitialPet = false;
    });
    await _selectPet(pet);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searched = false;
      _searchResults = [];
    });
    final results = await DBHelper.instance.searchClientsByPhone(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _addNewClient() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClientScreen()));
    if (!mounted) return;
    if (_searchController.text.trim().isNotEmpty) await _search();
  }

  Future<void> _selectClient(Client client) async {
    final pets = await DBHelper.instance.getPetsByClientId(client.id!);
    if (!mounted) return;
    setState(() {
      _selectedClient = client;
      _pets = pets;
      _step = _Step.pet;
    });
  }

  Future<void> _addNewPet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPetScreen(clientId: _selectedClient!.id!, clientName: _selectedClient!.name)),
    );
    if (!mounted) return;
    final pets = await DBHelper.instance.getPetsByClientId(_selectedClient!.id!);
    setState(() => _pets = pets);
  }

  /// عند اختيار أليفة بدون صورة، يجب إضافة صورة أولاً قبل المتابعة للخدمات
  /// تعديل يدوي مباشر لعداد الشاور - مفيد لأليفة لديها شاورات سابقة قبل
  /// تركيب التطبيق، أو لتصحيح العداد يدوياً في أي وقت
  Future<void> _editShowerCount() async {
    final controller = TextEditingController(text: (_showerProgress?['paidCount'] ?? 0).toString());

    final newValue = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل عداد الشاور'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عدد الشاورات (0 - 3)',
            helperText: 'مثال: أدخل 2 لو الأليفة لديها شاوران سابقان قبل تركيب التطبيق',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال رقم صحيح')),
                );
                return;
              }
              Navigator.pop(ctx, value > 3 ? 3 : value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (newValue == null || _selectedPet?.id == null) return;

    await DBHelper.instance.setPetShowerCount(_selectedPet!.id!, newValue);
    if (!mounted) return;
    setState(() {
      _showerProgress = {'paidCount': newValue, 'freeEligible': newValue >= 3};
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث عداد الشاور')));
  }

  Future<void> _selectPet(Pet pet) async {
    if (pet.imagePath == null || pet.imagePath!.isEmpty) {
      final updatedPet = await _requirePhotoThenContinue(pet);
      if (updatedPet == null) return; // لم تتم إضافة صورة - لا نكمل
      pet = updatedPet;
    }

    final progress = await DBHelper.instance.getPetShowerProgress(pet.id!);
    if (!mounted) return;
    setState(() {
      _selectedPet = pet;
      _showerProgress = progress;
      _selectedServices.clear();
      _useFreeShower = false;
      _step = _Step.services;
    });
  }

  Future<Pet?> _requirePhotoThenContinue(Pet pet) async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('صورة الأليفة مطلوبة'),
        content: const Text('هذا الأليف لا توجد له صورة، يرجى إضافة صورة قبل تسجيل الخدمة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة صورة الآن')),
        ],
      ),
    );
    if (proceed != true || !mounted) return null;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return null;

    final path = await ImagePickerHelper.pickAndSaveImage(source: source);
    if (path == null) return null;

    final updated = pet.copyWith(imagePath: path);
    await DBHelper.instance.updatePet(updated);
    if (!mounted) return null;

    // نحدّث القائمة المحلية لتعكس الصورة الجديدة أيضاً
    setState(() {
      _pets = _pets.map((p) => p.id == pet.id ? updated : p).toList();
    });
    return updated;
  }

  Future<void> _submit() async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار خدمة واحدة على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);

    final countsAsShower = GroomingServiceType.servicesCountAsShower(_selectedServices.toList());
    final isFree = _useFreeShower && countsAsShower;
    final service = GroomingService(
      petId: _selectedPet!.id!,
      services: _selectedServices.toList(),
      countsAsShower: countsAsShower,
      isFreeShower: isFree,
      status: GroomingStatus.pending,
      createdAt: DateHelper.nowDateTime(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    await DBHelper.instance.insertGroomingService(service);

    // تحديث عداد الشاور الفعلي: يصفّر عند استخدام المجاني، ويزيد بواحد عند
    // أي شاور مدفوع جديد
    if (countsAsShower) {
      if (isFree) {
        await DBHelper.instance.resetPetShowerCount(_selectedPet!.id!);
      } else {
        await DBHelper.instance.incrementPetShowerCount(_selectedPet!.id!);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الخدمة بنجاح')));

    // نعود لقائمة خدمات اليوم في نفس الشاشة (بداية جديدة) بدل الانتقال لشاشة أخرى
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GroomingScreen()),
      (route) => false,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case GroomingStatus.inProgress:
        return AppColors.warning;
      case GroomingStatus.completed:
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> item, String status) async {
    final id = item['id'] as int;
    await DBHelper.instance.updateGroomingServiceStatus(id, status);
    if (!mounted) return;

    if (status == GroomingStatus.completed) {
      final message = WhatsAppHelper.buildGroomingCompletedMessage(
        petName: item['pet_name'],
        gender: item['pet_gender'],
      );
      await SendToClientPrompt.show(context: context, phone: item['client_phone'], message: message);
    }

    if (!mounted) return;
    setState(_reloadTodayServices);
  }

  String get _title {
    switch (_step) {
      case _Step.client:
        return 'الشاور والحلاقة';
      case _Step.pet:
        return 'الشاور والحلاقة — اختر الأليفة';
      case _Step.services:
        return 'الشاور والحلاقة — الخدمات';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loadingInitialPet ? const Center(child: CircularProgressIndicator()) : _buildStepBody(),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _Step.client:
        return _buildClientStep();
      case _Step.pet:
        return _buildPetStep();
      case _Step.services:
        return _buildServicesStep();
    }
  }

  bool get _isSearchActive => _searching || _searched;

  Widget _buildClientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'ابحث برقم الجوال أو اسم العميل لإضافة خدمة',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              width: 56,
              child: ElevatedButton(
                onPressed: _searchController.text.trim().isEmpty ? null : _search,
                child: const Icon(Icons.search),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_searching) const Center(child: CircularProgressIndicator()),
        if (_searched && _searchResults.isEmpty) ...[
          const Text('لا يوجد عملاء مطابقين لبحثك', style: TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('إضافة عميل جديد'),
            onPressed: _addNewClient,
          ),
          const SizedBox(height: 10),
        ],
        if (_isSearchActive)
          Expanded(
            child: ListView(
              children: _searchResults
                  .map((c) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(c.name),
                          subtitle: Text(c.phone),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _selectClient(c),
                        ),
                      ))
                  .toList(),
            ),
          )
        else
          Expanded(child: _buildTodayServicesList()),
      ],
    );
  }

  Widget _buildTodayServicesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _todayServicesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('لا توجد خدمات مسجّلة اليوم'));

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final status = item['status'] as String;
            final services = ((item['services'] as String?) ?? '').split('|').where((s) => s.isNotEmpty).join(' + ');
            final imagePath = item['pet_image'] as String?;
            final hasPhoto = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();
            final isFree = (item['is_free_shower'] as int) == 1;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: hasPhoto ? FileImage(File(imagePath)) : null,
                      child: !hasPhoto ? const Icon(Icons.pets, color: Colors.grey, size: 28) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('العميل: ${item['client_name']}'),
                          Text('الخدمة: $services${isFree ? ' (مجاني)' : ''}'),
                          if (item['notes'] != null && (item['notes'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('ملاحظات: ${item['notes']}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                            ),
                          const SizedBox(height: 8),
                          PopupMenuButton<String>(
                            initialValue: status,
                            onSelected: (v) => _changeStatus(item, v),
                            itemBuilder: (context) => GroomingStatus.all
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _step = _Step.client),
          icon: const Icon(Icons.arrow_back),
          label: const Text('رجوع'),
        ),
        Text('العميل: ${_selectedClient!.name} — ${_selectedClient!.phone}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.pets),
            label: const Text('إضافة أليفة جديدة'),
            onPressed: _addNewPet,
          ),
        ),
        const SizedBox(height: 8),
        if (_pets.isEmpty)
          const Expanded(child: Center(child: Text('لا يوجد أليفات مسجلة لهذا العميل')))
        else
          Expanded(
            child: ListView(
              children: _pets.map((p) {
                final hasPhoto = p.imagePath != null && p.imagePath!.isNotEmpty;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: hasPhoto ? FileImage(File(p.imagePath!)) : null,
                      child: !hasPhoto ? const Icon(Icons.pets, color: Colors.grey) : null,
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(hasPhoto ? p.type : '${p.type} — بدون صورة ⚠️'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _selectPet(p),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildServicesStep() {
    final progress = _showerProgress;
    final freeEligible = progress != null && progress['freeEligible'] == true;
    final paidCount = progress != null ? progress['paidCount'] as int : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _step = _Step.pet),
          icon: const Icon(Icons.arrow_back),
          label: const Text('رجوع لاختيار أليفة أخرى'),
        ),
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: FileImage(File(_selectedPet!.imagePath!)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${_selectedPet!.name} (${_selectedClient!.name})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (freeEligible ? AppColors.success : AppColors.primaryLight).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الشاورات: $paidCount / 3', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _editShowerCount,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تعديل'),
                  ),
                ],
              ),
              if (freeEligible) ...[
                const SizedBox(height: 6),
                const Text('شاور مجاني مستحق 🎉', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('استخدام الشاور المجاني المستحق الآن'),
                  value: _useFreeShower,
                  onChanged: (v) => setState(() => _useFreeShower = v ?? false),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('اختر الخدمة (يمكن اختيار أكثر من صنف)', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: ListView(
            children: [
              ...GroomingServiceType.all.map((s) {
                return CheckboxListTile(
                  title: Text(s),
                  value: _selectedServices.contains(s),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedServices.add(s);
                      } else {
                        _selectedServices.remove(s);
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        if (_selectedServices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              children: _selectedServices.map((s) => Chip(label: Text(s))).toList(),
            ),
          ),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'جاري الحفظ...' : 'تسجيل الخدمة'),
            onPressed: _saving ? null : _submit,
          ),
        ),
      ],
    );
  }
}
