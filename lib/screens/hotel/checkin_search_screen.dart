import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../../widgets/info_card.dart';
import 'add_admission_screen.dart';

/// Screen for searching for a client (by name or phone number) to check a pet in for boarding/medical procedure
class CheckinSearchScreen extends StatefulWidget {
  const CheckinSearchScreen({super.key});

  @override
  State<CheckinSearchScreen> createState() => _CheckinSearchScreenState();
}

class _CheckinSearchScreenState extends State<CheckinSearchScreen> {
  final _searchController = TextEditingController();

  List<Client> _searchResults = [];
  bool _searching = false;
  bool _searched = false;

  Client? _selectedClient;
  List<Pet> _pets = [];

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searched = false;
      _searchResults = [];
      _selectedClient = null;
      _pets = [];
    });

    final results = await DBHelper.instance.searchClientsByPhone(query);

    setState(() {
      _searchResults = results;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _selectClient(Client client) async {
    final pets = await DBHelper.instance.getPetsByClientId(client.id!);
    if (!mounted) return;
    setState(() {
      _selectedClient = client;
      _pets = pets;
    });
  }

  void _changeClient() {
    setState(() {
      _selectedClient = null;
      _pets = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in — Search for Client')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedClient == null) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
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
              const SizedBox(height: 20),
              if (_searching) const Center(child: CircularProgressIndicator()),
              if (_searched && _searchResults.isEmpty)
                const Center(child: Text('No clients match your search', style: TextStyle(color: Colors.red))),
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
            ],
            if (_selectedClient != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Client: ${_selectedClient!.name} — ${_selectedClient!.phone}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  TextButton(onPressed: _changeClient, child: const Text('Change')),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Select Pet:'),
              const SizedBox(height: 8),
              Expanded(
                child: _pets.isEmpty
                    ? const Text('No pets registered for this client')
                    : ListView(
                        children: _pets
                            .map(
                              (pet) => Card(
                                child: ListTile(
                                  leading: const Icon(Icons.pets),
                                  title: Text(pet.name),
                                  subtitle: Row(
                                    children: [
                                      Text('${pet.type}  —  '),
                                      StatusBadge(status: pet.status),
                                    ],
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddAdmissionScreen(petId: pet.id!, petName: pet.name),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
