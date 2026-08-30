class Appointment {
  final int? id;
  final int petId;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final String reason;
  final String? notes;
  final String status; // من AppointmentStatus

  Appointment({
    this.id,
    required this.petId,
    required this.date,
    required this.time,
    required this.reason,
    this.notes,
    this.status = 'بانتظار',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'date': date,
      'time': time,
      'reason': reason,
      'notes': notes,
      'status': status,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as int?,
      petId: map['pet_id'] as int,
      date: map['date'] as String,
      time: map['time'] as String,
      reason: (map['reason'] as String?) ?? '',
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'بانتظار',
    );
  }

  Appointment copyWith({String? status}) {
    return Appointment(
      id: id,
      petId: petId,
      date: date,
      time: time,
      reason: reason,
      notes: notes,
      status: status ?? this.status,
    );
  }
}
