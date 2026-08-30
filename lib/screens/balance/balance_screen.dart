import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';

/// شاشة "رصيد" — إضافة/تعديل رصيد أي عميل، وعرض كل العملاء الذين لديهم رصيد فعلي فقط
class BalanceScreen extends StatefulWidget {
  final String? prefilledPhone;

  const BalanceScreen({super.key, this.prefilledPhone});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final _searchController = TextEditingController();

  List<Client> _searchResults = [];
  bool _searching = false;
  bool _searched = false;

  late Future<List<Client>> _balancesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.prefilledPhone != null && widget.prefilledPhone!.isNotEmpty) {
      _searchController.text = widget.prefilledPhone!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  void _reload() {
    _balancesFuture = DBHelper.instance.getClientsWithBalance();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searched = false;
      _searchResults = [];
    });

    final results = await DBHelper.instance.searchClientsByPhone(query);

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _editBalance(Client client) async {
    final controller = TextEditingController(
      text: client.balance == client.balance.roundToDouble()
          ? client.balance.toStringAsFixed(0)
          : client.balance.toString(),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('رصيد ${client.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(
            labelText: 'قيمة الرصيد',
            helperText: 'اكتب القيمة الجديدة الكاملة للرصيد (ضع 0 لتصفيره)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال رقم صحيح')),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == null || client.id == null) return;

    await DBHelper.instance.setClientBalance(client.id!, result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الرصيد')));

    setState(() {
      _reload();
      // نحدّث نتائج البحث الحالية أيضاً (إن وجدت) لتعكس القيمة الجديدة فوراً
      _searchResults = _searchResults
          .map((c) => c.id == client.id ? c.copyWith(balance: result) : c)
          .toList();
    });
  }

  String _formatBalance(double balance) {
    final isWhole = balance == balance.roundToDouble();
    return isWhole ? balance.toStringAsFixed(0) : balance.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رصيد العملاء')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'ابحث برقم الجوال أو اسم العميل',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _search,
                    child: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_searching) const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (_searched && _searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('لا يوجد عملاء مطابقين لبحثك', style: TextStyle(color: Colors.red)),
              ),
            if (_searchResults.isNotEmpty) ...[
              const Text('نتائج البحث', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ..._searchResults.map(
                (c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(c.name),
                    subtitle: Text(c.phone),
                    trailing: Text(
                      _formatBalance(c.balance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.balance > 0 ? AppColors.success : (c.balance < 0 ? AppColors.danger : AppColors.textLight),
                      ),
                    ),
                    onTap: () => _editBalance(c),
                  ),
                ),
              ),
              const Divider(height: 30),
            ],
            const Text('العملاء الذين لديهم رصيد حالياً', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<Client>>(
                future: _balancesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final clients = snapshot.data!;
                  if (clients.isEmpty) {
                    return const Center(child: Text('لا يوجد عملاء لديهم رصيد حالياً'));
                  }
                  return ListView.builder(
                    itemCount: clients.length,
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                          title: Text(c.name),
                          subtitle: Text(c.phone),
                          trailing: Text(
                            _formatBalance(c.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: c.balance > 0 ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          onTap: () => _editBalance(c),
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
