import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/admission.dart';
import '../../utils/date_helper.dart';
import '../../utils/image_picker_helper.dart';
import '../home_screen.dart';

class AddHotelScreen extends StatefulWidget {
  final int petId;
  final String petName;

  const AddHotelScreen({super.key, required this.petId, required this.petName});

  @override
  State<AddHotelScreen> createState() => _AddHotelScreenState();
}

class _AddHotelScreenState extends State<AddHotelScreen> {
  String _boardingType = BoardingType.normal;
  DateTime? _expectedExitDate;
  final _notesController = TextEditingController();
  String? _contractImagePath;
  bool _saving = false;

  Future<void> _pickContractImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo of the contract with the camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await ImagePickerHelper.pickAndSaveImage(source: source);
    if (path != null) setState(() => _contractImagePath = path);
  }

  Future<void> _pickExpectedExitDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _expectedExitDate = date);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final admission = Admission(
      petId: widget.petId,
      type: AdmissionType.hotel,
      boardingType: _boardingType,
      entryDate: DateHelper.nowDateTime(),
      expectedExitDate: _expectedExitDate != null ? DateHelper.formatDate(_expectedExitDate!) : null,
      entryContractImage: _contractImagePath,
      status: PetStatus.inHotel,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await DBHelper.instance.insertAdmission(admission);
    await DBHelper.instance.updatePetStatus(widget.petId, PetStatus.inHotel);

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${widget.petName}" checked into the hotel')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Boarding — ${widget.petName}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text('Boarding Type', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: const Text(BoardingType.normal),
              value: BoardingType.normal,
              groupValue: _boardingType,
              onChanged: (v) => setState(() => _boardingType = v!),
            ),
            RadioListTile<String>(
              title: const Text(BoardingType.treatment),
              value: BoardingType.treatment,
              groupValue: _boardingType,
              onChanged: (v) => setState(() => _boardingType = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Expected Exit Date'),
              subtitle: Text(_expectedExitDate != null ? DateHelper.formatDate(_expectedExitDate!) : 'Select a date'),
              trailing: const Icon(Icons.edit),
              onTap: _pickExpectedExitDate,
            ),
            const Divider(),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: Text(_contractImagePath == null ? 'Take Contract Photo' : 'Contract photo selected ✓'),
              onPressed: _pickContractImage,
            ),
            if (_contractImagePath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_contractImagePath!), height: 160, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Check In to Hotel'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
