import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';

/// شاشة تعديل بيانات عميل موجود مسبقاً
class EditClientScreen extends StatefulWidget {
  final Client client;

  const EditClientScreen({super.key, required this.client});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late final TextEditingController _civilIdController;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.client.phone);
    _nameController = TextEditingController(text: widget.client.name);
    _civilIdController = TextEditingController(text: widget.client.civilId ?? '');
    _notesController = TextEditingController(text: widget.client.notes ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _civilIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final newPhone = _phoneController.text.trim();
    if (newPhone != widget.client.phone) {
      final existing = await DBHelper.instance.getClientByPhone(newPhone);
      if (existing != null && existing.id != widget.client.id) {
        setState(() => _saving = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم الجوال مسجل مسبقاً لعميل آخر')),
        );
        return;
      }
    }

    final updated = widget.client.copyWith(
      phone: newPhone,
      name: _nameController.text.trim(),
      civilId: _civilIdController.text.trim().isEmpty ? null : _civilIdController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    await DBHelper.instance.updateClient(updated);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات العميل')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الجوال *', prefixIcon: Icon(Icons.phone)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'رقم الجوال إجباري';
                  if (v.trim().length < 9) return 'رقم الجوال غير صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم العميل *', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم العميل إجباري' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _civilIdController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'السجل المدني / رقم الهوية / الإقامة (اختياري)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
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
