import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../../models/appointment.dart';
import '../../utils/date_helper.dart';
import '../clinic/add_visit_screen.dart';

/// Screen for adding a new appointment or editing/deleting an existing one
class AddAppointmentScreen extends StatefulWidget {
  final Appointment? existingAppointment;
  final String? prefilledPhone;

  const AddAppointmentScreen({super.key, this.existingAppointment, this.prefilledPhone});

  bool get isEditing => existingAppointment != null;

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _searchController = TextEditingController();

  List<Client> _searchResults = [];
  bool _searching = false;
  bool _searched = false;

  Client? _selectedClient;
  List<Pet> _pets = [];
  Pet? _selectedPet;

  bool _loadingExisting = false;

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _appointmentType = AppointmentType.vaccination;
  String _status = AppointmentStatus.pending;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExisting();
    } else if (widget.prefilledPhone != null && widget.prefilledPhone!.isNotEmpty) {
      _searchController.text = widget.prefilledPhone!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);

    final appt = widget.existingAppointment!;
    final pet = await DBHelper.instance.getPetById(appt.petId);

    if (pet != null) {
      final client = await DBHelper.instance.getClientById(pet.clientId);
      final pets = await DBHelper.instance.getPetsByClientId(pet.clientId);
      Pet? matchedPet;
      for (final p in pets) {
        if (p.id == pet.id) matchedPet = p;
      }
      _selectedClient = client;
      _pets = pets;
      _selectedPet = matchedPet ?? pet;
    }

    final parts = appt.time.split(':');
    _date = DateTime.tryParse(appt.date) ?? DateTime.now();
    _time = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    _appointmentType = AppointmentType.all.contains(appt.reason) ? appt.reason : AppointmentType.vaccination;
    _status = AppointmentStatus.all.contains(appt.status) ? appt.status : AppointmentStatus.pending;
    _notesController.text = appt.notes ?? '';

    if (!mounted) return;
    setState(() => _loadingExisting = false);
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
      _selectedPet = null;
    });
  }

  void _changeClient() {
    setState(() {
      _selectedClient = null;
      _pets = [];
      _selectedPet = null;
      _searchResults = [];
      _searched = false;
      _searchController.clear();
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }

  Future<void> _save() async {
    if (_selectedPet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the pet first')),
      );
      return;
    }

    setState(() => _saving = true);

    final dateStr = DateHelper.formatDate(_date);
    final timeStr = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    if (widget.isEditing) {
      final updated = Appointment(
        id: widget.existingAppointment!.id,
        petId: _selectedPet!.id!,
        date: dateStr,
        time: timeStr,
        reason: _appointmentType,
        notes: notes,
        status: _status,
      );
      await DBHelper.instance.updateAppointment(updated);
    } else {
      final appointment = Appointment(
        petId: _selectedPet!.id!,
        date: dateStr,
        time: timeStr,
        reason: _appointmentType,
        notes: notes,
      );
      await DBHelper.instance.insertAppointment(appointment);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment saved')));
    Navigator.pop(context, true);
  }

  Future<void> _attendNow() async {
    final appt = widget.existingAppointment!;
    await DBHelper.instance.updateAppointmentStatus(appt.id!, AppointmentStatus.attended);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          petId: appt.petId,
          petName: _selectedPet?.name ?? '',
          appointmentId: appt.id,
          appointmentReason: appt.reason,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text('Are you sure you want to delete this appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    await DBHelper.instance.deleteAppointment(widget.existingAppointment!.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment deleted')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Appointment' : 'Add Appointment'),
        actions: [
          if (widget.isEditing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.isEditing && _selectedClient == null) ...[
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
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('No clients match your search', style: TextStyle(color: Colors.red)),
                      ),
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
                        if (!widget.isEditing)
                          TextButton(onPressed: _changeClient, child: const Text('Change')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          const Text('Select Pet', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_pets.isEmpty) const Text('No pets registered for this client'),
                          ..._pets.map(
                            (p) => RadioListTile<Pet>(
                              title: Text(p.name),
                              subtitle: Text(p.type),
                              value: p,
                              groupValue: _selectedPet,
                              onChanged: (v) => setState(() => _selectedPet = v),
                            ),
                          ),
                          const Divider(),
                          const Text('Appointment Type', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...AppointmentType.all.map(
                            (t) => RadioListTile<String>(
                              title: Text(t),
                              value: t,
                              groupValue: _appointmentType,
                              onChanged: (v) => setState(() => _appointmentType = v!),
                            ),
                          ),
                          const Divider(),
                          if (widget.isEditing) ...[
                            const Text('Appointment Status', style: TextStyle(fontWeight: FontWeight.bold)),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: AppointmentStatus.all.map((s) {
                                final selected = s == _status;
                                return ChoiceChip(
                                  label: Text(s),
                                  selected: selected,
                                  onSelected: (_) => setState(() => _status = s),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Attend appointment now — open clinic visit'),
                                onPressed: _attendNow,
                              ),
                            ),
                            const Divider(),
                          ],
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Date'),
                            subtitle: Text(DateHelper.formatDate(_date)),
                            trailing: const Icon(Icons.edit),
                            onTap: _pickDate,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.access_time),
                            title: const Text('Time'),
                            subtitle: Text(_time.format(context)),
                            trailing: const Icon(Icons.edit),
                            onTap: _pickTime,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_saving ? 'Saving...' : 'Save Appointment'),
                              onPressed: _saving ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
