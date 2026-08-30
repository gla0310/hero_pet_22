class Visit {
  final int? id;
  final int petId;
  final String date; // yyyy-MM-dd
  final String reason; // From VisitReason
  final String? description; // Examination / general notes
  final String? diagnosis; // Diagnosis
  final String? treatment; // Treatment
  final String? recommendations; // Recommendations
  final int? appointmentId; // The related appointment (if the visit resulted from an appointment being "attended")

  Visit({
    this.id,
    required this.petId,
    required this.date,
    required this.reason,
    this.description,
    this.diagnosis,
    this.treatment,
    this.recommendations,
    this.appointmentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'date': date,
      'reason': reason,
      'description': description,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'recommendations': recommendations,
      'appointment_id': appointmentId,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'] as int?,
      petId: map['pet_id'] as int,
      date: map['date'] as String,
      reason: map['reason'] as String,
      description: map['description'] as String?,
      diagnosis: map['diagnosis'] as String?,
      treatment: map['treatment'] as String?,
      recommendations: map['recommendations'] as String?,
      appointmentId: map['appointment_id'] as int?,
    );
  }
}
