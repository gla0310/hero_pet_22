import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../models/pet.dart';
import '../../models/visit.dart';
import '../../models/appointment.dart';
import '../../models/admission.dart';
import '../../models/admission_note.dart';
import '../../widgets/info_card.dart';
import '../../widgets/section_title.dart';
import '../../utils/date_helper.dart';
import '../../database/db_helper.dart';
import '../hotel/checkout_screen.dart';
import '../forms/form_submission_view_screen.dart';
import 'edit_pet_screen.dart';

class PetProfileScreen extends StatelessWidget {
  final Pet pet;
  final String clientName;
  final List<Visit> visits;
  final List<Appointment> appointments;
  final List<Admission> admissions;
  final Map<int, List<AdmissionNote>> notesByAdmission;

  const PetProfileScreen({
    super.key,
    required this.pet,
    required this.clientName,
    required this.visits,
    required this.appointments,
    required this.admissions,
    this.notesByAdmission = const {},
  });

  void _viewImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(child: Image.file(File(path))),
      ),
    );
  }

  Widget _contractThumb(BuildContext context, String? path, String label) {
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () => _viewImage(context, path),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(path), width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _editPet(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPetScreen(pet: pet)),
    );
    // Go back to the client profile so it automatically refreshes with the new data
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _archivePet(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Pet'),
        content: Text('"${pet.name}" will disappear from the client profile, while all their medical records remain saved and can be restored from the archive. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirm != true || pet.id == null || !context.mounted) return;

    await DBHelper.instance.archivePet(pet.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pet archived')));
    Navigator.pop(context);
  }

  Color _appointmentStatusColor(String status) {
    switch (status) {
      case AppointmentStatus.attended:
        return AppColors.success;
      case AppointmentStatus.noShow:
        return AppColors.danger;
      case AppointmentStatus.cancelled:
        return AppColors.textLight;
      case AppointmentStatus.rescheduled:
        return AppColors.warning;
      default:
        return AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastVisit = visits.isNotEmpty ? visits.first : null;
    final today = DateHelper.today();
    final upcomingAppointments = appointments.where((a) => a.date.compareTo(today) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name}\'s Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit pet information', onPressed: () => _editPet(context)),
          IconButton(icon: const Icon(Icons.archive_outlined), tooltip: 'Archive pet', onPressed: () => _archivePet(context)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: pet.imagePath != null ? FileImage(File(pet.imagePath!)) : null,
                child: pet.imagePath == null ? const Icon(Icons.pets, size: 40, color: Colors.grey) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Owner: $clientName', style: const TextStyle(color: AppColors.textLight)),
                    const SizedBox(height: 6),
                    StatusBadge(status: pet.status),
                  ],
                ),
              ),
            ],
          ),
          if (pet.status == PetStatus.inHotel || pet.status == PetStatus.inClinic) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(pet.status == PetStatus.inHotel ? Icons.logout : Icons.check_circle),
                label: Text(pet.status == PetStatus.inHotel ? 'Check Out from Hotel' : 'Deliver Pet'),
                onPressed: () async {
                  final active = admissions.firstWhere(
                    (a) => a.status == pet.status,
                    orElse: () => admissions.first,
                  );
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CheckoutScreen(admission: active, petName: pet.name)),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
          const Divider(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(label: 'Type', value: pet.type),
                  if (pet.breed != null) InfoRow(label: 'Breed', value: pet.breed!),
                  if (pet.gender != null) InfoRow(label: 'Gender', value: pet.gender == 'Female' ? 'Female' : 'Male'),
                  if (pet.birthDate != null) InfoRow(label: 'Age/Birth Date', value: pet.birthDate!),
                  if (pet.weight != null) InfoRow(label: 'Weight', value: '${pet.weight} kg'),
                  if (pet.color != null) InfoRow(label: 'Color', value: pet.color!),
                  if (pet.microchip != null && pet.microchip!.isNotEmpty) InfoRow(label: 'Microchip', value: pet.microchip!),
                  if (pet.notes != null) InfoRow(label: 'Notes', value: pet.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(label: 'Last Visit', value: lastVisit != null ? '${lastVisit.date} — ${lastVisit.reason}' : 'None'),
                  InfoRow(
                    label: 'Next Appointment',
                    value: upcomingAppointments.isNotEmpty
                        ? '${upcomingAppointments.first.date} — ${upcomingAppointments.first.time}'
                        : 'None',
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle(title: 'Clinic Visit History', icon: Icons.local_hospital),
          if (visits.isEmpty) const Text('No visit history'),
          ...visits.map((v) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(v.date, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                      if (v.description != null && v.description!.isNotEmpty) Text('Exam/Notes: ${v.description}'),
                      if (v.diagnosis != null && v.diagnosis!.isNotEmpty) Text('Diagnosis: ${v.diagnosis}'),
                      if (v.treatment != null && v.treatment!.isNotEmpty) Text('Treatment: ${v.treatment}'),
                      if (v.recommendations != null && v.recommendations!.isNotEmpty) Text('Recommendations: ${v.recommendations}'),
                    ],
                  ),
                ),
              )),
          const SectionTitle(title: 'All Appointments', icon: Icons.event_note),
          if (appointments.isEmpty) const Text('No appointments'),
          ...appointments.map((a) => Card(
                child: ListTile(
                  title: Text('${a.reason} — ${a.date} ${a.time}'),
                  subtitle: a.notes != null ? Text(a.notes!) : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _appointmentStatusColor(a.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _appointmentStatusColor(a.status)),
                    ),
                    child: Text(
                      a.status,
                      style: TextStyle(color: _appointmentStatusColor(a.status), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
              )),
          const SectionTitle(title: 'Hotel & Medical Procedures History', icon: Icons.hotel),
          if (admissions.isEmpty) const Text('No hotel or medical procedure history'),
          ...admissions.map((a) {
            final notes = notesByAdmission[a.id] ?? [];
            final title = a.isProcedure ? AdmissionKind.procedure : (a.boardingType ?? '-');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        StatusBadge(status: a.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Check-in: ${a.entryDate}'),
                    Text('Expected check-out: ${DateHelper.displayDate(a.expectedExitDate)}'),
                    Text('Actual check-out: ${a.actualExitDate ?? "Not yet"}'),
                    if (a.notes != null && a.notes!.isNotEmpty) Text('Check-in notes: ${a.notes}'),
                    _contractThumb(context, a.entryContractImage, 'Check-in Contract'),
                    _contractThumb(context, a.exitContractImage, 'Pickup Contract'),
                    if (notes.isNotEmpty) ...[
                      const Divider(),
                      const Text('Notes During Stay:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ...notes.map((n) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('• ${n.text} (${n.dateTime})', style: const TextStyle(color: AppColors.textLight)),
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SectionTitle(title: 'Shower Counter', icon: Icons.content_cut),
          _ShowerCounterCard(petId: pet.id!),
          const SectionTitle(title: 'Digital Forms', icon: Icons.description_outlined),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DBHelper.instance.getFormSubmissionsForPet(pet.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final submissions = snapshot.data!;
              if (submissions.isEmpty) return const Text('No forms saved for this pet yet');
              return Column(
                children: submissions.map((s) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                      title: Text(s['template_name']),
                      subtitle: Text(s['submitted_at']),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FormSubmissionViewScreen(submission: s)),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/// Shower counter card within the pet profile - shows the current count and
/// allows editing it manually (e.g. for a pet that had previous showers before
/// the app was installed)
class _ShowerCounterCard extends StatefulWidget {
  final int petId;

  const _ShowerCounterCard({required this.petId});

  @override
  State<_ShowerCounterCard> createState() => _ShowerCounterCardState();
}

class _ShowerCounterCardState extends State<_ShowerCounterCard> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = DBHelper.instance.getPetShowerProgress(widget.petId);
  }

  Future<void> _edit(int currentCount) async {
    final controller = TextEditingController(text: currentCount.toString());
    final newValue = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Shower Counter'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of Showers (0 - 3)',
            helperText: 'Example: enter 2 if the pet had two previous showers before the app was installed',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }
              Navigator.pop(ctx, value > 3 ? 3 : value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newValue == null) return;

    await DBHelper.instance.setPetShowerCount(widget.petId, newValue);
    if (!mounted) return;
    setState(() => _future = DBHelper.instance.getPetShowerProgress(widget.petId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final paidCount = snapshot.data!['paidCount'] as int;
        final freeEligible = snapshot.data!['freeEligible'] as bool;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: (freeEligible ? AppColors.success : AppColors.primaryLight).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Showers: $paidCount / 3', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => _edit(paidCount),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              if (freeEligible) ...[
                const SizedBox(height: 4),
                const Text('Free shower earned', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        );
      },
    );
  }
}
