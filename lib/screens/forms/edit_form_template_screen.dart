import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';

/// إنشاء أو تعديل قالب استمارة: الاسم، نوع الخدمة، نص الشروط، تفعيل/إيقاف،
/// وإدارة الحقول الإضافية (نص / نص طويل / مربع اختيار) داخل القالب.
class EditFormTemplateScreen extends StatefulWidget {
  final int? templateId;

  const EditFormTemplateScreen({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  State<EditFormTemplateScreen> createState() => _EditFormTemplateScreenState();
}

class _EditFormTemplateScreenState extends State<EditFormTemplateScreen> {
  final _nameController = TextEditingController();
  final _termsController = TextEditingController();
  String _serviceType = FormServiceType.checkinHotelNormal;
  bool _active = true;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _fields = [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final template = await DBHelper.instance.getFormTemplateById(widget.templateId!);
    final fields = await DBHelper.instance.getFormFields(widget.templateId!);
    if (!mounted || template == null) return;
    setState(() {
      _nameController.text = template['name'];
      _termsController.text = template['terms_text'] ?? '';
      _serviceType = template['service_type'];
      _active = (template['active'] as int) == 1;
      _fields = fields;
      _loading = false;
    });
  }

  Future<void> _addField() async {
    final labelController = TextEditingController();
    String fieldType = 'text';
    bool required = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة حقل للاستمارة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'نص الحقل / السؤال'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: fieldType,
                decoration: const InputDecoration(labelText: 'نوع الحقل'),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('حقل نصي قصير')),
                  DropdownMenuItem(value: 'textarea', child: Text('حقل نصي طويل')),
                  DropdownMenuItem(value: 'checkbox', child: Text('مربع اختيار (Checkbox)')),
                ],
                onChanged: (v) => setDialogState(() => fieldType = v ?? fieldType),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حقل إلزامي'),
                value: required,
                onChanged: (v) => setDialogState(() => required = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );

    if (result != true || labelController.text.trim().isEmpty) return;

    if (widget.isEditing) {
      await DBHelper.instance.addFormField(
        templateId: widget.templateId!,
        fieldType: fieldType,
        label: labelController.text.trim(),
        required: required,
      );
      final fields = await DBHelper.instance.getFormFields(widget.templateId!);
      if (!mounted) return;
      setState(() => _fields = fields);
    } else {
      // القالب لم يُحفظ بعد - نحتفظ بالحقل محلياً حتى الحفظ الأول
      setState(() {
        _fields.add({
          'id': null,
          'field_type': fieldType,
          'label': labelController.text.trim(),
          'required': required ? 1 : 0,
        });
      });
    }
  }

  Future<void> _deleteField(Map<String, dynamic> field, int index) async {
    if (field['id'] != null) {
      await DBHelper.instance.deleteFormField(field['id'] as int);
    }
    setState(() => _fields.removeAt(index));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة اسم الاستمارة')),
      );
      return;
    }
    setState(() => _saving = true);

    if (widget.isEditing) {
      await DBHelper.instance.updateFormTemplate(
        id: widget.templateId!,
        name: _nameController.text.trim(),
        serviceType: _serviceType,
        termsText: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        active: _active,
      );
    } else {
      final newId = await DBHelper.instance.insertFormTemplate(
        name: _nameController.text.trim(),
        serviceType: _serviceType,
        termsText: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        active: _active,
      );
      // نحفظ الحقول التي أُضيفت محلياً قبل حفظ القالب لأول مرة
      for (final field in _fields) {
        await DBHelper.instance.addFormField(
          templateId: newId,
          fieldType: field['field_type'],
          label: field['label'],
          required: (field['required'] as int) == 1,
        );
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الاستمارة')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'تعديل الاستمارة' : 'استمارة جديدة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الاستمارة',
                      prefixIcon: Icon(Icons.title),
                      hintText: 'مثال: استمارة دخول فندقة عادية',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _serviceType,
                    decoration: const InputDecoration(
                      labelText: 'تظهر تلقائياً عند',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: FormServiceType.all
                        .map((s) => DropdownMenuItem(value: s, child: Text(FormServiceType.label(s))))
                        .toList(),
                    onChanged: (v) => setState(() => _serviceType = v ?? _serviceType),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الاستمارة مفعّلة'),
                    subtitle: const Text('عند الإيقاف، لن تظهر هذه الاستمارة تلقائياً للعميل'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const Divider(height: 30),
                  TextField(
                    controller: _termsController,
                    decoration: const InputDecoration(
                      labelText: 'نص الشروط والأحكام',
                      prefixIcon: Icon(Icons.gavel),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('حقول إضافية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(
                        onPressed: _addField,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة حقل'),
                      ),
                    ],
                  ),
                  if (_fields.isEmpty) const Text('لا يوجد حقول إضافية بعد'),
                  ..._fields.asMap().entries.map((entry) {
                    final i = entry.key;
                    final f = entry.value;
                    final required = (f['required'] as int) == 1;
                    final typeLabel = f['field_type'] == 'checkbox'
                        ? 'مربع اختيار'
                        : (f['field_type'] == 'textarea' ? 'نص طويل' : 'نص قصير');
                    return Card(
                      child: ListTile(
                        title: Text(f['label']),
                        subtitle: Text('$typeLabel${required ? ' — إلزامي' : ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () => _deleteField(f, i),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الاستمارة'),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}
