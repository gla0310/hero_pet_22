import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';

/// شاشة الأرشيف: تعرض العملاء والأليفات المؤرشفين مع إمكانية الاستعادة
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  late Future<List<Client>> _archivedClientsFuture;
  late Future<List<Map<String, dynamic>>> _archivedPetsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _archivedClientsFuture = DBHelper.instance.getArchivedClients();
    _archivedPetsFuture = DBHelper.instance.getArchivedPetsWithClient();
  }

  Future<void> _restoreClient(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة العميل'),
        content: Text('هل تريد استعادة "${client.name}" وإظهاره في القوائم الرئيسية مجدداً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (confirm != true || client.id == null) return;

    await DBHelper.instance.restoreClient(client.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استعادة العميل')));
    setState(_reload);
  }

  Future<void> _restorePet(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة الأليفة'),
        content: Text('هل تريد استعادة "${item['name']}" وإظهارها في ملف العميل مجدداً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (confirm != true) return;

    await DBHelper.instance.restorePet(item['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استعادة الأليفة')));
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأرشيف'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'العملاء المؤرشفون'),
              Tab(text: 'الأليفات المؤرشفة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<Client>>(
              future: _archivedClientsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final clients = snapshot.data!;
                if (clients.isEmpty) return const Center(child: Text('لا يوجد عملاء مؤرشفون'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: clients.length,
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_off, color: AppColors.textLight),
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        trailing: TextButton.icon(
                          onPressed: () => _restoreClient(c),
                          icon: const Icon(Icons.restore),
                          label: const Text('استعادة'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _archivedPetsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final pets = snapshot.data!;
                if (pets.isEmpty) return const Center(child: Text('لا يوجد أليفات مؤرشفة'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pets.length,
                  itemBuilder: (context, i) {
                    final p = pets[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.pets, color: AppColors.textLight),
                        title: Text(p['name']),
                        subtitle: Text('العميل: ${p['client_name']} — ${p['client_phone']}'),
                        trailing: TextButton.icon(
                          onPressed: () => _restorePet(p),
                          icon: const Icon(Icons.restore),
                          label: const Text('استعادة'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
