import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/admission.dart';
import '../../models/admission_note.dart';
import '../../utils/date_helper.dart';

/// تتيح إضافة/تعديل/حذف ملاحظات للأليفة أثناء وجودها في الفندقة أو العيادة
/// دون أن يُعتبر ذلك تسجيل خروج لها.
class AdmissionNotesScreen extends StatefulWidget {
  final Admission admission;
  final String petName;

  const AdmissionNotesScreen({super.key, required this.admission, required this.petName});

  @override
  State<AdmissionNotesScreen> createState() => _AdmissionNotesScreenState();
}

class _AdmissionNotesScreenState extends State<AdmissionNotesScreen> {
  late Future<List<AdmissionNote>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = DBHelper.instance.getNotesForAdmission(widget.admission.id!);
  }

  Future<void> _showNoteDialog({AdmissionNote? existing}) async {
    final controller = TextEditingController(text: existing?.text ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة ملاحظة' : 'تعديل الملاحظة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'اكتب الملاحظة هنا...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    if (existing == null) {
      await DBHelper.instance.insertAdmissionNote(
        AdmissionNote(admissionId: widget.admission.id!, dateTime: DateHelper.nowDateTime(), text: result),
      );
    } else {
      await DBHelper.instance.updateAdmissionNote(
        AdmissionNote(id: existing.id, admissionId: existing.admissionId, dateTime: DateHelper.nowDateTime(), text: result),
      );
    }
    setState(_reload);
  }

  Future<void> _deleteNote(AdmissionNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملاحظة'),
        content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.instance.deleteAdmissionNote(note.id!);
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.admission;
    final kindLabel = a.type == AdmissionType.procedure ? AdmissionKind.procedure : (a.boardingType ?? '-');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.petName} — الملاحظات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة ملاحظة'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نوع الحالة: $kindLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('تاريخ الدخول: ${a.entryDate}', style: const TextStyle(color: AppColors.textLight)),
                Text('الخروج المتوقع: ${DateHelper.displayDate(a.expectedExitDate)}', style: const TextStyle(color: AppColors.textLight)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<AdmissionNote>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final notes = snapshot.data!;
                if (notes.isEmpty) {
                  return const Center(child: Text('لا توجد ملاحظات بعد، اضغط "إضافة ملاحظة"'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    return Card(
                      child: ListTile(
                        title: Text(note.text),
                        subtitle: Text(note.dateTime, style: const TextStyle(color: AppColors.textLight)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              onPressed: () => _showNoteDialog(existing: note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.danger),
                              onPressed: () => _deleteNote(note),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
