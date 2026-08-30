class AdmissionNote {
  final int? id;
  final int admissionId;
  final String dateTime; // yyyy-MM-dd HH:mm
  final String text;

  AdmissionNote({
    this.id,
    required this.admissionId,
    required this.dateTime,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admission_id': admissionId,
      'date_time': dateTime,
      'text': text,
    };
  }

  factory AdmissionNote.fromMap(Map<String, dynamic> map) {
    return AdmissionNote(
      id: map['id'] as int?,
      admissionId: map['admission_id'] as int,
      dateTime: map['date_time'] as String,
      text: map['text'] as String,
    );
  }
}
