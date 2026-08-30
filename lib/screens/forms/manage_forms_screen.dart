import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import 'edit_form_template_screen.dart';

/// شاشة "إدارة الاستمارات" - تسمح للمسؤول بإنشاء/تعديل/حذف قوالب
/// الاستمارات الإلكترونية وتحديد نوع الخدمة التي تظهر عندها كل استمارة.
class ManageFormsScreen extends StatefulWidget {
  const ManageFormsScreen({super.key});

  @override
  State<ManageFormsScreen> createState() => _ManageFormsScreenState();
}

class _ManageFormsScreenState extends State<ManageFormsScreen> {
  late Future<List<Map<String, dynamic>>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _templatesFuture = DBHelper.instance.getFormTemplates();
  }

  Future<void> _deleteTemplate(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الاستمارة'),
        content: Text('هل تريد حذف قالب "$name"؟ الاستمارات المُعتمدة سابقاً باستخدامه تبقى محفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await DBHelper.instance.deleteFormTemplate(id);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الاستمارات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditFormTemplateScreen()),
          );
          if (created == true) setState(_reload);
        },
        icon: const Icon(Icons.add),
        label: const Text('استمارة جديدة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا يوجد استمارات بعد. اضغط "استمارة جديدة" لإنشاء أول استمارة إلكترونية '
                  '(مثل استمارة دخول فندقة أو استمارة إجراء طبي).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, i) {
              final t = templates[i];
              final active = (t['active'] as int) == 1;
              return Card(
                child: ListTile(
                  leading: Icon(Icons.description, color: active ? AppColors.primary : AppColors.textLight),
                  title: Text(t['name']),
                  subtitle: Text(
                    '${FormServiceType.label(t['service_type'])} — ${active ? 'مفعّلة' : 'موقوفة'}',
                    style: TextStyle(color: active ? AppColors.success : AppColors.textLight),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => _deleteTemplate(t['id'] as int, t['name']),
                  ),
                  onTap: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditFormTemplateScreen(templateId: t['id'] as int)),
                    );
                    if (updated == true) setState(_reload);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
