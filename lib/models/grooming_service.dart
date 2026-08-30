class GroomingService {
  final int? id;
  final int petId;
  final List<String> services; // From GroomingServiceType
  final bool countsAsShower;
  final bool isFreeShower;
  final String status; // From GroomingStatus
  final String createdAt;
  final String? completedAt;
  final String? notes;

  GroomingService({
    this.id,
    required this.petId,
    required this.services,
    required this.countsAsShower,
    this.isFreeShower = false,
    this.status = 'Pending',
    required this.createdAt,
    this.completedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'services': services.join('|'),
      'counts_as_shower': countsAsShower ? 1 : 0,
      'is_free_shower': isFreeShower ? 1 : 0,
      'status': status,
      'created_at': createdAt,
      'completed_at': completedAt,
      'notes': notes,
    };
  }

  factory GroomingService.fromMap(Map<String, dynamic> map) {
    final rawServices = map['services'] as String? ?? '';
    return GroomingService(
      id: map['id'] as int?,
      petId: map['pet_id'] as int,
      services: rawServices.isEmpty ? [] : rawServices.split('|'),
      countsAsShower: (map['counts_as_shower'] as int?) == 1,
      isFreeShower: (map['is_free_shower'] as int?) == 1,
      status: (map['status'] as String?) ?? 'Pending',
      createdAt: map['created_at'] as String,
      completedAt: map['completed_at'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
