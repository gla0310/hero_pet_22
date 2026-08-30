import '../core/constants.dart';

class Admission {
  final int? id;
  final int petId;
  final String type; // AdmissionType.hotel أو AdmissionType.procedure
  final String? boardingType; // BoardingType (فقط عند type = hotel)
  final String? procedureName; // فقط عند type = procedure
  final String entryDate; // yyyy-MM-dd HH:mm
  final String? expectedExitDate; // فقط للفندقة
  final String? actualExitDate; // تاريخ ووقت الخروج/التسليم الفعلي
  final String? entryContractImage;
  final String? exitContractImage;
  final String status; // PetStatus
  final String? notes;

  Admission({
    this.id,
    required this.petId,
    required this.type,
    this.boardingType,
    this.procedureName,
    required this.entryDate,
    this.expectedExitDate,
    this.actualExitDate,
    this.entryContractImage,
    this.exitContractImage,
    required this.status,
    this.notes,
  });

  bool get isHotel => type == AdmissionType.hotel;
  bool get isProcedure => type == AdmissionType.procedure;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'type': type,
      'boarding_type': boardingType,
      'procedure_name': procedureName,
      'entry_date': entryDate,
      'expected_exit_date': expectedExitDate,
      'actual_exit_date': actualExitDate,
      'entry_contract_image': entryContractImage,
      'exit_contract_image': exitContractImage,
      'status': status,
      'notes': notes,
    };
  }

  factory Admission.fromMap(Map<String, dynamic> map) {
    return Admission(
      id: map['id'] as int?,
      petId: map['pet_id'] as int,
      type: map['type'] as String,
      boardingType: map['boarding_type'] as String?,
      procedureName: map['procedure_name'] as String?,
      entryDate: map['entry_date'] as String,
      expectedExitDate: map['expected_exit_date'] as String?,
      actualExitDate: map['actual_exit_date'] as String?,
      entryContractImage: map['entry_contract_image'] as String?,
      exitContractImage: map['exit_contract_image'] as String?,
      status: map['status'] as String,
      notes: map['notes'] as String?,
    );
  }

  Admission copyWith({
    String? actualExitDate,
    String? exitContractImage,
    String? status,
    String? notes,
  }) {
    return Admission(
      id: id,
      petId: petId,
      type: type,
      boardingType: boardingType,
      procedureName: procedureName,
      entryDate: entryDate,
      expectedExitDate: expectedExitDate,
      actualExitDate: actualExitDate ?? this.actualExitDate,
      entryContractImage: entryContractImage,
      exitContractImage: exitContractImage ?? this.exitContractImage,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
