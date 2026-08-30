import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';

/// Archive screen: shows archived clients and pets with the ability to restore them
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
        title: const Text('Restore Client'),
        content: Text('Do you want to restore "${client.name}" and show them in the main lists again?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true || client.id == null) return;

    await DBHelper.instance.restoreClient(client.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client restored')));
    setState(_reload);
  }

  Future<void> _restorePet(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Pet'),
        content: Text('Do you want to restore "${item['name']}" and show them in the client\'s profile again?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;

    await DBHelper.instance.restorePet(item['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pet restored')));
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Archive'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Archived Clients'),
              Tab(text: 'Archived Pets'),
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
                if (clients.isEmpty) return const Center(child: Text('No archived clients'));
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
                          label: const Text('Restore'),
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
                if (pets.isEmpty) return const Center(child: Text('No archived pets'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pets.length,
                  itemBuilder: (context, i) {
                    final p = pets[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.pets, color: AppColors.textLight),
                        title: Text(p['name']),
                        subtitle: Text('Client: ${p['client_name']} — ${p['client_phone']}'),
                        trailing: TextButton.icon(
                          onPressed: () => _restorePet(p),
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore'),
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
