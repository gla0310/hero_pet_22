import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../utils/date_helper.dart';
import '../client/client_profile_screen.dart';

class AllClientsScreen extends StatefulWidget {
  const AllClientsScreen({super.key});

  @override
  State<AllClientsScreen> createState() => _AllClientsScreenState();
}

class _AllClientsScreenState extends State<AllClientsScreen> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = DBHelper.instance.getRecentClientsWithPetCount();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openClient(BuildContext context, String phone) async {
    final profile = await DBHelper.instance.getClientFullProfile(phone);
    if (profile == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProfileScreen(
          client: profile['client'],
          petsWithDetails: List<Map<String, dynamic>>.from(profile['pets']),
        ),
      ),
    );
  }

  bool _matches(Client client) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return client.name.toLowerCase().contains(q) || client.phone.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جميع العملاء')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ابحث برقم الجوال أو اسم العميل',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final allItems = snapshot.data!;
                  if (allItems.isEmpty) return const Center(child: Text('لا يوجد عملاء بعد'));

                  final items = allItems.where((item) => _matches(Client.fromMap(item))).toList();
                  if (items.isEmpty) {
                    return const Center(child: Text('لا يوجد عملاء مطابقين لبحثك'));
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final client = Client.fromMap(item);
                      final petCount = item['pet_count'] ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(client.name),
                          subtitle: Text('${client.phone} — ${DateHelper.displayDate(client.createdAt)} — عدد الأليفات: $petCount'),
                          onTap: () => _openClient(context, client.phone),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
