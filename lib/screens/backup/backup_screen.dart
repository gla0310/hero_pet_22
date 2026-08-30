import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/db_helper.dart';
import '../../utils/date_helper.dart';
import '../archive/archive_screen.dart';
import '../forms/manage_forms_screen.dart';

/// شاشة بسيطة للنسخ الاحتياطي واسترجاع قاعدة البيانات المحلية
/// النسخ الاحتياطي: مشاركة/حفظ نسخة من ملف قاعدة البيانات (hero_pet.db)
/// الاسترجاع: اختيار ملف نسخة احتياطية سابقة واستبدال قاعدة البيانات الحالية بها
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _working = false;
  String? _message;

  Future<void> _backup() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final dbPath = await DBHelper.instance.dbPath;
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        setState(() => _message = 'لا توجد قاعدة بيانات حتى الآن لعمل نسخة منها');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final backupName = 'hero_pet_backup_${DateHelper.nowDateTime().replaceAll(RegExp(r'[^0-9]'), '_')}.db';
      final backupPath = p.join(tempDir.path, backupName);
      await dbFile.copy(backupPath);

      await Share.shareXFiles([XFile(backupPath)], text: 'نسخة احتياطية من بيانات hero pet');
      setState(() => _message = 'تم إنشاء النسخة الاحتياطية بنجاح');
    } catch (e) {
      setState(() => _message = 'حدث خطأ أثناء النسخ الاحتياطي: $e');
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاسترجاع'),
        content: const Text('سيتم استبدال جميع البيانات الحالية بالنسخة المختارة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، استرجاع')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) {
        setState(() => _working = false);
        return;
      }

      final pickedPath = result.files.single.path!;
      await DBHelper.instance.close();

      final dbPath = await DBHelper.instance.dbPath;
      await File(pickedPath).copy(dbPath);

      setState(() => _message = 'تم استرجاع البيانات بنجاح. الرجاء إعادة تشغيل التطبيق.');
    } catch (e) {
      setState(() => _message = 'حدث خطأ أثناء الاسترجاع: $e');
    } finally {
      setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاسترجاع')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'يمكنك أخذ نسخة احتياطية من بيانات العيادة وحفظها في مكان آمن، '
              'أو استرجاع نسخة سابقة عند الحاجة.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.backup),
              label: const Text('إنشاء نسخة احتياطية'),
              onPressed: _working ? null : _backup,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('استرجاع نسخة احتياطية'),
              onPressed: _working ? null : _restore,
            ),
            const SizedBox(height: 24),
            if (_working) const Center(child: CircularProgressIndicator()),
            if (_message != null)
              Text(_message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const Divider(height: 40),
            const Text(
              'العملاء والأليفات المؤرشفون لا يزالون محفوظين بالكامل ويمكن استعادتهم من هنا.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.archive_outlined),
              label: const Text('عرض الأرشيف'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('إدارة الاستمارات'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageFormsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
