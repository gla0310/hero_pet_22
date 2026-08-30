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

/// Simple screen for backing up and restoring the local database
/// Backup: share/save a copy of the database file (hero_pet.db)
/// Restore: pick a previous backup file and replace the current database with it
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
        setState(() => _message = 'There is no database yet to back up');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final backupName = 'hero_pet_backup_${DateHelper.nowDateTime().replaceAll(RegExp(r'[^0-9]'), '_')}.db';
      final backupPath = p.join(tempDir.path, backupName);
      await dbFile.copy(backupPath);

      await Share.shareXFiles([XFile(backupPath)], text: 'Backup of hero pet data');
      setState(() => _message = 'Backup created successfully');
    } catch (e) {
      setState(() => _message = 'An error occurred during backup: $e');
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text('All current data will be replaced with the selected backup. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Restore')),
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

      setState(() => _message = 'Data restored successfully. Please restart the app.');
    } catch (e) {
      setState(() => _message = 'An error occurred during restore: $e');
    } finally {
      setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and Restore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You can back up the clinic\'s data and save it in a safe place, '
              'or restore a previous backup when needed.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.backup),
              label: const Text('Create Backup'),
              onPressed: _working ? null : _backup,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restore Backup'),
              onPressed: _working ? null : _restore,
            ),
            const SizedBox(height: 24),
            if (_working) const Center(child: CircularProgressIndicator()),
            if (_message != null)
              Text(_message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const Divider(height: 40),
            const Text(
              'Archived clients and pets remain fully saved and can be restored from here.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.archive_outlined),
              label: const Text('View Archive'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('Manage Forms'),
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
