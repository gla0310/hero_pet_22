import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../utils/date_helper.dart';
import 'create_vaccination_package_screen.dart';

/// شاشة باقات التطعيمات: تعرض كل باقة (مرتبطة بأليفة محددة) مع اسم العميل
/// واسم الأليفة، وقائمة تطعيماتها أفقياً مع حالة كل تطعيمة (أُعطيت أم لا)
class VaccinationPackagesScreen extends StatefulWidget {
  const VaccinationPackagesScreen({super.key});

  @override
  State<VaccinationPackagesScreen> createState() => _VaccinationPackagesScreenState();
}

class _VaccinationPackagesScreenState extends State<VaccinationPackagesScreen> {
  late Future<List<Map<String, dynamic>>> _packagesFuture;
  final Map<int, List<Map<String, dynamic>>> _itemsCache = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _itemsCache.clear();
    _packagesFuture = DBHelper.instance.getVaccinationPackagesWithDetails();
  }

  Future<List<Map<String, dynamic>>> _itemsFor(int packageId) async {
    if (_itemsCache.containsKey(packageId)) return _itemsCache[packageId]!;
    final items = await DBHelper.instance.getVaccinationPackageItems(packageId);
    _itemsCache[packageId] = items;
    return items;
  }

  Future<void> _toggleItem(int packageId, Map<String, dynamic> item) async {
    final given = (item['given'] as int) == 1;
    await DBHelper.instance.setVaccineItemGiven(
      itemId: item['id'] as int,
      given: !given,
      date: !given ? DateHelper.today() : null,
    );
    if (!mounted) return;
    setState(() => _itemsCache.remove(packageId));
  }

  Future<void> _deletePackage(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الباقة'),
        content: const Text('هل تريد حذف باقة التطعيمات هذه بكل تطعيماتها؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await DBHelper.instance.deleteVaccinationPackage(id);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('باقات التطعيمات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateVaccinationPackageScreen()),
          );
          if (created == true) setState(_reload);
        },
        icon: const Icon(Icons.add),
        label: const Text('باقة جديدة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _packagesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final packages = snapshot.data!;
          if (packages.isEmpty) {
            return const Center(child: Text('لا يوجد باقات تطعيمات بعد — اضغط "باقة جديدة" لإضافة أول باقة'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, i) {
              final pkg = packages[i];
              final packageId = pkg['id'] as int;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pkg['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('العميل: ${pkg['client_name']} — ${pkg['client_phone']}',
                                    style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () => _deletePackage(packageId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _itemsFor(packageId),
                        builder: (context, itemSnap) {
                          if (!itemSnap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final items = itemSnap.data!;
                          if (items.isEmpty) return const Text('لا يوجد تطعيمات في هذه الباقة');
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: items.map((item) {
                                final given = (item['given'] as int) == 1;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: FilterChip(
                                    label: Text(item['vaccine_name']),
                                    selected: given,
                                    checkmarkColor: Colors.white,
                                    selectedColor: AppColors.success,
                                    onSelected: (_) => _toggleItem(packageId, item),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
