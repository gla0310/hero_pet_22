import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../client/add_client_screen.dart';

/// Screen for creating a new vaccination package: select client → select pet
/// → pick vaccines from a checklist → save the package linked to the pet
class CreateVaccinationPackageScreen extends StatefulWidget {
  const CreateVaccinationPackageScreen({super.key});

  @override
  State<CreateVaccinationPackageScreen> createState() => _CreateVaccinationPackageScreenState();
}

enum _Step { client, pet, vaccines }

class _CreateVaccinationPackageScreenState extends State<CreateVaccinationPackageScreen> {
  _Step _step = _Step.client;

  // Step 1: Search for client
  final _searchController = TextEditingController();
  List<Client> _searchResults = [];
  bool _searching = false;
  bool _searched = false;
  Client? _selectedClient;

  // Step 2: Select pet
  List<Pet> _pets = [];
  Pet? _selectedPet;

  // Step 3: Vaccine list
  List<Map<String, dynamic>> _masterVaccines = [];
  final Set<String> _selectedVaccines = {};
  final _newVaccineController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newVaccineController.dispose();
    super.dispose();
  }

  Future<void> _addNewClient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddClientScreen()),
    );
    if (!mounted) return;
    // After returning from adding the client and their pet, we repeat the
    // same search automatically so the new client shows up right away if
    // they were added with the same name/number
    if (_searchController.text.trim().isNotEmpty) {
      await _search();
    }
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

  Future<void> _selectClient(Client client) async {
    final pets = await DBHelper.instance.getPetsByClientId(client.id!);
    if (!mounted) return;
    setState(() {
      _selectedClient = client;
      _pets = pets;
      _step = _Step.pet;
    });
  }

  Future<void> _selectPet(Pet pet) async {
    final vaccines = await DBHelper.instance.getMasterVaccines();
    if (!mounted) return;
    setState(() {
      _selectedPet = pet;
      _masterVaccines = vaccines;
      _step = _Step.vaccines;
    });
  }

  Future<void> _addNewVaccineToList() async {
    final name = _newVaccineController.text.trim();
    if (name.isEmpty) return;
    await DBHelper.instance.addMasterVaccine(name);
    final vaccines = await DBHelper.instance.getMasterVaccines();
    if (!mounted) return;
    setState(() {
      _masterVaccines = vaccines;
      _selectedVaccines.add(name);
      _newVaccineController.clear();
    });
  }

  Future<void> _save() async {
    if (_selectedVaccines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one vaccine')),
      );
      return;
    }
    setState(() => _saving = true);
    await DBHelper.instance.createVaccinationPackageForPet(
      petId: _selectedPet!.id!,
      vaccineNames: _selectedVaccines.toList(),
      name: 'Package for ${_selectedPet!.name}',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Package saved')));
    Navigator.pop(context, true);
  }

  String get _title {
    switch (_step) {
      case _Step.client:
        return 'New Package — Select Client';
      case _Step.pet:
        return 'New Package — Select Pet';
      case _Step.vaccines:
        return 'New Package — Vaccines';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildStepBody(),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _Step.client:
        return _buildClientStep();
      case _Step.pet:
        return _buildPetStep();
      case _Step.vaccines:
        return _buildVaccinesStep();
    }
  }

  Widget _buildClientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 16),
        if (_searching) const Center(child: CircularProgressIndicator()),
        if (_searched && _searchResults.isEmpty) ...[
          const Text('No clients match your search', style: TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add New Client and Pet'),
            onPressed: _addNewClient,
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: ListView(
            children: _searchResults
                .map((c) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => _selectClient(c),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _step = _Step.client),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Select Another Client'),
        ),
        Text('Client: ${_selectedClient!.name} — ${_selectedClient!.phone}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_pets.isEmpty)
          const Expanded(child: Center(child: Text('No pets registered for this client')))
        else
          Expanded(
            child: ListView(
              children: _pets
                  .map((p) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.pets),
                          title: Text(p.name),
                          subtitle: Text(p.type),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _selectPet(p),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildVaccinesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _step = _Step.pet),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Select Another Pet'),
        ),
        Text('Pet: ${_selectedPet!.name} (${_selectedClient!.name})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Select the vaccines included in the package:', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: ListView(
            children: [
              ..._masterVaccines.map((v) {
                final name = v['name'] as String;
                return CheckboxListTile(
                  title: Text(name),
                  value: _selectedVaccines.contains(name),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedVaccines.add(name);
                      } else {
                        _selectedVaccines.remove(name);
                      }
                    });
                  },
                );
              }),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newVaccineController,
                      decoration: const InputDecoration(labelText: 'Add a new vaccine to the list'),
                      onSubmitted: (_) => _addNewVaccineToList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary),
                    onPressed: _addNewVaccineToList,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Package'),
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}
