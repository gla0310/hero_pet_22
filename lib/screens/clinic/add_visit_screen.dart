import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../../models/visit.dart';
import '../../models/appointment.dart';
import '../../utils/date_helper.dart';
import '../home_screen.dart';

class AddVisitScreen extends StatefulWidget {
  final int petId;
  final String petName;

  /// If the visit was opened from an appointment marked "attended", the
  /// appointment id is passed here to link the visit to it directly and
  /// auto-fill the visit reason from the appointment reason
  final int? appointmentId;
  final String? appointmentReason;

  const AddVisitScreen({
    super.key,
    required this.petId,
    required this.petName,
    this.appointmentId,
    this.appointmentReason,
  });

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  DateTime _visitDate = DateTime.now();
  late String _reason;
  final _descController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _recommendationsController = TextEditingController();
  bool _saving = false;

  // Optional follow-up appointment data
  bool _addFollowUpAppointment = false;
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _appointmentTime = TimeOfDay.now();
  String _appointmentReason = FollowUpReason.followUp;
  final _appointmentOtherController = TextEditingController();
  final _appointmentNotesController = TextEditingController();

  // Client balance (displayed directly during the visit)
  Client? _client;
  bool _loadingClient = true;

  // This pet's vaccination package (loaded automatically if one exists)
  Map<String, dynamic>? _package;
  List<Map<String, dynamic>> _packageItems = [];
  bool _loadingPackage = true;

  @override
  void initState() {
    super.initState();
    _reason = (widget.appointmentReason != null && VisitReason.all.contains(widget.appointmentReason))
        ? widget.appointmentReason!
        : VisitReason.followUp;
    _loadClientBalance();
    _loadPackage();
  }

  @override
  void dispose() {
    _descController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _recommendationsController.dispose();
    _appointmentOtherController.dispose();
    _appointmentNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadClientBalance() async {
    final pet = await DBHelper.instance.getPetById(widget.petId);
    if (pet == null) {
      if (mounted) setState(() => _loadingClient = false);
      return;
    }
    final client = await DBHelper.instance.getClientById(pet.clientId);
    if (!mounted) return;
    setState(() {
      _client = client;
      _loadingClient = false;
    });
  }

  Future<void> _loadPackage() async {
    final package = await DBHelper.instance.getVaccinationPackageForPet(widget.petId);
    if (package == null) {
      if (mounted) setState(() => _loadingPackage = false);
      return;
    }
    final items = await DBHelper.instance.getVaccinationPackageItems(package['id'] as int);
    if (!mounted) return;
    setState(() {
      _package = package;
      _packageItems = items;
      _loadingPackage = false;
    });
  }

  Future<void> _toggleVaccineItem(Map<String, dynamic> item) async {
    final given = (item['given'] as int) == 1;
    // If it was already given in a previous visit, don't allow unchecking it here to avoid losing the linked visit record
    if (given && item['given_visit_id'] != null) return;

    await DBHelper.instance.setVaccineItemGiven(
      itemId: item['id'] as int,
      given: !given,
      date: !given ? DateHelper.formatDate(_visitDate) : null,
    );
    final items = await DBHelper.instance.getVaccinationPackageItems(_package!['id'] as int);
    if (!mounted) return;
    setState(() => _packageItems = items);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _visitDate = date);
  }

  Future<void> _pickAppointmentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _appointmentDate = date);
  }

  Future<void> _pickAppointmentTime() async {
    final time = await showTimePicker(context: context, initialTime: _appointmentTime);
    if (time != null) setState(() => _appointmentTime = time);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // If the visit results from an appointment "attendance", make sure its status is "attended"
    if (widget.appointmentId != null) {
      await DBHelper.instance.updateAppointmentStatus(widget.appointmentId!, AppointmentStatus.attended);
    }

    final visit = Visit(
      petId: widget.petId,
      date: DateHelper.formatDate(_visitDate),
      reason: _reason,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      diagnosis: _diagnosisController.text.trim().isEmpty ? null : _diagnosisController.text.trim(),
      treatment: _treatmentController.text.trim().isEmpty ? null : _treatmentController.text.trim(),
      recommendations: _recommendationsController.text.trim().isEmpty ? null : _recommendationsController.text.trim(),
      appointmentId: widget.appointmentId,
    );
    final visitId = await DBHelper.instance.insertVisit(visit);

    // Link every vaccine item that was just checked to this visit (add the visit id to any that were checked without a link)
    for (final item in _packageItems) {
      final given = (item['given'] as int) == 1;
      if (given && item['given_visit_id'] == null) {
        await DBHelper.instance.setVaccineItemGiven(
          itemId: item['id'] as int,
          given: true,
          date: DateHelper.formatDate(_visitDate),
          visitId: visitId,
        );
      }
    }

    // If the staff member enabled the "add follow-up appointment" option, create the appointment automatically
    if (_addFollowUpAppointment) {
      final reasonText = _appointmentReason == FollowUpReason.other
          ? (_appointmentOtherController.text.trim().isEmpty ? FollowUpReason.other : _appointmentOtherController.text.trim())
          : _appointmentReason;

      final appointment = Appointment(
        petId: widget.petId,
        date: DateHelper.formatDate(_appointmentDate),
        time: '${_appointmentTime.hour.toString().padLeft(2, '0')}:${_appointmentTime.minute.toString().padLeft(2, '0')}',
        reason: reasonText,
        notes: _appointmentNotesController.text.trim().isEmpty ? null : _appointmentNotesController.text.trim(),
      );
      await DBHelper.instance.insertAppointment(appointment);
    }

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visit for "${widget.petName}" recorded${_addFollowUpAppointment ? ' and follow-up appointment saved' : ''}')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  String _formatBalance(double balance) {
    final isWhole = balance == balance.roundToDouble();
    return isWhole ? balance.toStringAsFixed(0) : balance.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Clinic Visit — ${widget.petName}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Client balance - shown directly without navigating to another page
          if (!_loadingClient && _client != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Text(
                    'Client balance: ${_formatBalance(_client!.balance)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ],
              ),
            ),

          // This pet's vaccination package (if any) - shown automatically
          if (!_loadingPackage && _package != null) ...[
            const Text('This Pet\'s Vaccination Package', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _packageItems.map((item) {
                final given = (item['given'] as int) == 1;
                return FilterChip(
                  label: Text(item['vaccine_name']),
                  selected: given,
                  checkmarkColor: Colors.white,
                  selectedColor: AppColors.success,
                  onSelected: (_) => _toggleVaccineItem(item),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the vaccine when it is given now during this visit',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const Divider(height: 32),
          ],

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Visit Date'),
            subtitle: Text(DateHelper.formatDate(_visitDate)),
            trailing: const Icon(Icons.edit),
            onTap: _pickDate,
          ),
          const Divider(),
          const Text('Visit Reason', style: TextStyle(fontWeight: FontWeight.bold)),
          ...VisitReason.all.map(
            (r) => RadioListTile<String>(
              title: Text(r),
              value: r,
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v!),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Examination / General Notes',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diagnosisController,
            decoration: const InputDecoration(
              labelText: 'Diagnosis',
              prefixIcon: Icon(Icons.medical_information_outlined),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _treatmentController,
            decoration: const InputDecoration(
              labelText: 'Treatment',
              prefixIcon: Icon(Icons.medication_outlined),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recommendationsController,
            decoration: const InputDecoration(
              labelText: 'Recommendations',
              prefixIcon: Icon(Icons.lightbulb_outline),
            ),
            maxLines: 3,
          ),
          const Divider(height: 32),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addFollowUpAppointment,
            title: const Text('Add Follow-up Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
            onChanged: (v) => setState(() => _addFollowUpAppointment = v ?? false),
          ),
          if (_addFollowUpAppointment) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Appointment Date'),
              subtitle: Text(DateHelper.formatDate(_appointmentDate)),
              trailing: const Icon(Icons.edit),
              onTap: _pickAppointmentDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Time'),
              subtitle: Text(_appointmentTime.format(context)),
              trailing: const Icon(Icons.edit),
              onTap: _pickAppointmentTime,
            ),
            const SizedBox(height: 8),
            const Text('Appointment Reason', style: TextStyle(fontWeight: FontWeight.bold)),
            ...FollowUpReason.all.map(
              (r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _appointmentReason,
                onChanged: (v) => setState(() => _appointmentReason = v!),
              ),
            ),
            if (_appointmentReason == FollowUpReason.other)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _appointmentOtherController,
                  decoration: const InputDecoration(labelText: 'Enter the appointment reason'),
                ),
              ),
            TextField(
              controller: _appointmentNotesController,
              decoration: const InputDecoration(
                labelText: 'Follow-up Appointment Notes',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Visit'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
