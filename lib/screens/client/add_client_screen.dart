import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../pet/add_pet_screen.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _civilIdController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final phone = _phoneController.text.trim();
    final existing = await DBHelper.instance.getClientByPhone(phone);
    if (existing != null) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الجوال مسجل مسبقاً لعميل آخر')),
      );
      return;
    }

    final client = Client(
      phone: phone,
      name: _nameController.text.trim(),
      civilId: _civilIdController.text.trim().isEmpty ? null : _civilIdController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    final id = await DBHelper.instance.insertClient(client);

    setState(() => _saving = false);
    if (!mounted) return;

    // بعد حفظ العميل ننتقل مباشرة إلى إضافة أليفة له
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AddPetScreen(clientId: id, clientName: client.name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عميل جديد')),
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
                    : const Icon(Icons.arrow_back),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ ومتابعة لإضافة أليفة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
