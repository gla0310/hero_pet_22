import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/pet.dart';
import '../../utils/image_picker_helper.dart';

/// شاشة تعديل بيانات أليفة موجودة مسبقاً (كل الحقول بدون استثناء)
class EditPetScreen extends StatefulWidget {
  final Pet pet;

  const EditPetScreen({super.key, required this.pet});

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _weightController;
  late final TextEditingController _colorController;
  late final TextEditingController _microchipController;
  late final TextEditingController _notesController;

  late String _type;
  String? _gender;
  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _nameController = TextEditingController(text: pet.name);
    _breedController = TextEditingController(text: pet.breed ?? '');
    _birthDateController = TextEditingController(text: pet.birthDate ?? '');
    _weightController = TextEditingController(text: pet.weight?.toString() ?? '');
    _colorController = TextEditingController(text: pet.color ?? '');
    _microchipController = TextEditingController(text: pet.microchip ?? '');
    _notesController = TextEditingController(text: pet.notes ?? '');
    _type = PetTypes.common.contains(pet.type) ? pet.type : PetTypes.common.first;
    _gender = pet.gender;
    _imagePath = pet.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _birthDateController.dispose();
    _weightController.dispose();
    _colorController.dispose();
    _microchipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
    setState(() => _saving = true);

    final updated = widget.pet.copyWith(
      name: _nameController.text.trim(),
      type: _type,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      gender: _gender,
      birthDate: _birthDateController.text.trim().isEmpty ? null : _birthDateController.text.trim(),
      weight: double.tryParse(_weightController.text.trim()),
      color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
      imagePath: _imagePath,
      microchip: _microchipController.text.trim().isEmpty ? null : _microchipController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await DBHelper.instance.updatePet(updated);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تعديل بيانات ${widget.pet.name}')),
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الأليفة *', prefixIcon: Icon(Icons.badge)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الأليفة إجباري' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'النوع', prefixIcon: Icon(Icons.category)),
                items: PetTypes.common.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: 'السلالة', prefixIcon: Icon(Icons.pets)),
              ),
              const SizedBox(height: 16),
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
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(
                  labelText: 'تاريخ الميلاد أو العمر',
                  prefixIcon: Icon(Icons.cake),
                  hintText: 'مثال: 2023-05-01 أو "سنتين"',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'الوزن (كجم)', prefixIcon: Icon(Icons.monitor_weight)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(labelText: 'اللون', prefixIcon: Icon(Icons.palette)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _microchipController,
                decoration: const InputDecoration(labelText: 'رقم المايكروشيب', prefixIcon: Icon(Icons.memory)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)),
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
