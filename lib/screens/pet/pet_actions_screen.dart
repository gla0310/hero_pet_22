import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../hotel/add_admission_screen.dart';
import '../clinic/add_visit_screen.dart';
import '../grooming/grooming_screen.dart';
import '../home_screen.dart';

/// Shown right after adding a new pet, letting the staff member pick the appropriate action
class PetActionsScreen extends StatelessWidget {
  final int petId;
  final String petName;
  final String clientName;

  const PetActionsScreen({
    super.key,
    required this.petId,
    required this.petName,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Saved')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 60),
            const SizedBox(height: 12),
            Text(
              '"$petName" was successfully added for $clientName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            const Text('Choose the appropriate action now (optional):', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.hotel),
              label: const Text('Hotel'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddAdmissionScreen(
                    petId: petId,
                    petName: petName,
                    initialKind: AdmissionKind.hotelNormal,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.medical_services),
              label: const Text('Medical Procedure'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddAdmissionScreen(
                    petId: petId,
                    petName: petName,
                    initialKind: AdmissionKind.procedure,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.local_hospital),
              label: const Text('Clinic (Visit Only)'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddVisitScreen(petId: petId, petName: petName)),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.content_cut),
              label: const Text('Shower & Grooming'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroomingScreen(initialPetId: petId)),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
