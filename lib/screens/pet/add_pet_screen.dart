import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/pet.dart';
import '../../utils/image_picker_helper.dart';
import 'pet_actions_screen.dart';

/// شاشة إضافة أليفة جديدة (تُستخدم بعد إضافة عميل جديد أو من ملف عميل موجود)
/// الحقول المطلوبة فقط: الاسم، النوع، الجنس، الصورة، العمر.
/// باقي البيانات (السلالة، الوزن، اللون، المايكروشيب، الملاحظات...) تُضاف
/// لاحقاً من شاشة "تعديل بيانات الأليفة" إن احتاجها الموظف.
class AddPetScreen extends StatefulWidget {
  final int clientId;
  final String clientName;

  const AddPetScreen({super.key, required this.clientId, required this.clientName});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();

  String _type = PetTypes.common.first;
  String? _gender;
  String? _imagePath;
  bool _saving = false;

  Future<void> _pickImage() async {
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
    if (source == null) return;
    final path = await ImagePickerHelper.pickAndSaveImage(source: source);
    if (path != null) setState(() => _imagePath = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار جنس الأليفة')),
      );
      return;
    }
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صورة الأليفة إجبارية')),
      );
      return;
    }

    setState(() => _saving = true);

    final pet = Pet(
      clientId: widget.clientId,
      name: _nameController.text.trim(),
      type: _type,
      gender: _gender,
      birthDate: _birthDateController.text.trim(),
      imagePath: _imagePath,
    );

    final id = await DBHelper.instance.insertPet(pet);
    setState(() => _saving = false);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PetActionsScreen(
          petId: id,
          petName: pet.name,
          clientName: widget.clientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إضافة أليفة — ${widget.clientName}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                    child: _imagePath == null
                        ? const Icon(Icons.add_a_photo, size: 32, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'صورة الأليفة *',
                  style: TextStyle(
                    fontSize: 12,
                    color: _imagePath == null ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الأليفة *', prefixIcon: Icon(Icons.badge)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الأليفة إجباري' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'النوع *', prefixIcon: Icon(Icons.category)),
                items: PetTypes.common.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              const Text('الجنس *', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('ذكر'),
                      value: 'ذكر',
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('أنثى'),
                      value: 'أنثى',
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(
                  labelText: 'العمر *',
                  prefixIcon: Icon(Icons.cake),
                  hintText: 'مثال: سنتين، أو 2023-05-01',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'عمر الأليفة إجباري' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الأليفة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
