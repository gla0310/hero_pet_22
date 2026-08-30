import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';

/// "Balance" screen — add/edit any client's balance, and show only clients who actually have a balance
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
        title: Text('${client.name}\'s Balance'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(
            labelText: 'Balance Amount',
            helperText: 'Enter the new full balance amount (enter 0 to reset it)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || client.id == null) return;

    await DBHelper.instance.setClientBalance(client.id!, result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balance updated')));

    setState(() {
      _reload();
      // Also update the current search results (if any) to reflect the new value immediately
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
      appBar: AppBar(title: const Text('Client Balances')),
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
                      labelText: 'Search by phone number or client name',
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
                child: Text('No clients match your search', style: TextStyle(color: Colors.red)),
              ),
            if (_searchResults.isNotEmpty) ...[
              const Text('Search Results', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Clients with a Current Balance', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<Client>>(
                future: _balancesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final clients = snapshot.data!;
                  if (clients.isEmpty) {
                    return const Center(child: Text('No clients currently have a balance'));
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
