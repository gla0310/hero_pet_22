class Reminder {
  final int? id;
  final int appointmentId;
  final String date; // yyyy-MM-dd
  final String message;

  Reminder({
    this.id,
    required this.appointmentId,
    required this.date,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'date': date,
      'message': message,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      appointmentId: map['appointment_id'] as int,
      date: map['date'] as String,
      message: map['message'] as String,
    );
  }
}
