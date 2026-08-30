import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/admission.dart';
import '../../utils/date_helper.dart';
import 'checkout_screen.dart';

/// شاشة تسجيل الخروج: تعرض كل الأليفات المتواجدة حالياً في الفندقة مباشرة
/// (بدون الحاجة للبحث)، مع إمكانية البحث عن عميل معيّن أيضاً.
class CheckoutSearchScreen extends StatefulWidget {
  const CheckoutSearchScreen({super.key});

  @override
  State<CheckoutSearchScreen> createState() => _CheckoutSearchScreenState();
}

class _CheckoutSearchScreenState extends State<CheckoutSearchScreen> {
  final _searchController = TextEditingController();

  List<Client> _searchResults = [];
  bool _searching = false;
  bool _searched = false;

  Client? _selectedClient;
  List<Map<String, dynamic>> _admissions = [];

  late Future<List<Map<String, dynamic>>> _currentlyPresentFuture;

  @override
  void initState() {
    super.initState();
    _reloadCurrentlyPresent();
  }

  void _reloadCurrentlyPresent() {
    _currentlyPresentFuture = DBHelper.instance.getCurrentlyPresentWithDetails();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searched = false;
      _searchResults = [];
      _selectedClient = null;
      _admissions = [];
    });

    final results = await DBHelper.instance.searchClientsByPhone(query);

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _selectClient(Client client) async {
    final admissions = await DBHelper.instance.getActiveAdmissionsByPhone(client.phone);
    if (!mounted) return;
    setState(() {
      _selectedClient = client;
      _admissions = admissions;
    });
  }

  void _changeClient() {
    setState(() {
      _selectedClient = null;
      _admissions = [];
      _searchResults = [];
      _searched = false;
      _searchController.clear();
    });
  }

  String _kindLabel(Map<String, dynamic> item) {
    if (item['type'] == AdmissionType.procedure) return AdmissionKind.procedure;
    return item['boarding_type'] ?? '-';
  }

  Future<void> _goToCheckout(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          admission: Admission.fromMap(item),
          petName: item['pet_name'],
        ),
      ),
    );
    if (result == true) {
      setState(_reloadCurrentlyPresent);
      if (_selectedClient != null) await _selectClient(_selectedClient!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل خروج')),
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
                      labelText: 'ابحث برقم الجوال أو اسم العميل (اختياري)',
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
            const SizedBox(height: 16),
            if (_searching) const Center(child: CircularProgressIndicator()),
            if (_searched && _searchResults.isEmpty && _selectedClient == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('لا يوجد عملاء مطابقين لبحثك', style: TextStyle(color: Colors.red)),
              ),

            // نتائج البحث (إن وُجدت ولم يُختر عميل بعد)
            if (_searchResults.isNotEmpty && _selectedClient == null)
              Expanded(
                child: ListView(
                  children: _searchResults
                      .map(
                        (c) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(c.name),
                            subtitle: Text(c.phone),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () => _selectClient(c),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            // عميل محدد من نتائج البحث: نعرض أليفاته فقط
            if (_selectedClient != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'العميل: ${_selectedClient!.name} — ${_selectedClient!.phone}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  TextButton(onPressed: _changeClient, child: const Text('رجوع للكل')),
                ],
              ),
              const SizedBox(height: 12),
              if (_admissions.isEmpty)
                const Expanded(child: Center(child: Text('لا يوجد أليفات موجودة حالياً لهذا العميل')))
              else
                Expanded(
                  child: ListView(
                    children: _admissions.map((item) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.pets, color: AppColors.statusInHotel),
                          title: Text(item['pet_name']),
                          subtitle: Text('${_kindLabel(item)} — دخول: ${item['entry_date']}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _goToCheckout(item),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],

            // الوضع الافتراضي: لا بحث نشط ولا عميل مختار — نعرض كل المتواجدين حالياً
            if (_selectedClient == null && _searchResults.isEmpty && !_searching) ...[
              const Text('المتواجدون حالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _currentlyPresentFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Center(child: Text('لا يوجد أليفات موجودة حالياً'));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final daysLate = DateHelper.daysLate(item['expected_exit_date']);
                        final isOverdue = daysLate > 0;
                        return Card(
                          color: isOverdue ? AppColors.danger.withOpacity(0.06) : null,
                          child: ListTile(
                            leading: Icon(Icons.pets, color: isOverdue ? AppColors.danger : AppColors.statusInHotel),
                            title: Text(item['pet_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${item['client_name']} — ${item['client_phone']}\n${_kindLabel(item)} — دخول: ${item['entry_date']}'
                              '${isOverdue ? '\nمتأخر عن الخروج — $daysLate يوم' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _goToCheckout(item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
