class Pet {
  final int? id;
  final int clientId;
  final String name;
  final String type;
  final String? breed;
  final String? gender; // ذكر / أنثى
  final String? birthDate; // yyyy-MM-dd (اختياري)
  final double? weight;
  final String? color;
  final String? imagePath;
  final String? microchip; // رقم المايكروشيب (اختياري)
  final String? notes;
  final String status; // من PetStatus
  final bool archived;
  final int showerCount; // عداد الشاور (0-3) - قابل للتعديل اليدوي من الموظف

  Pet({
    this.id,
    required this.clientId,
    required this.name,
    required this.type,
    this.breed,
    this.gender,
    this.birthDate,
    this.weight,
    this.color,
    this.imagePath,
    this.microchip,
    this.notes,
    this.status = 'طبيعي',
    this.archived = false,
    this.showerCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'name': name,
      'type': type,
      'breed': breed,
      'gender': gender,
      'birth_date': birthDate,
      'weight': weight,
      'color': color,
      'image_path': imagePath,
      'microchip': microchip,
      'notes': notes,
      'status': status,
      'archived': archived ? 1 : 0,
      'shower_count': showerCount,
    };
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] as int?,
      clientId: map['client_id'] as int,
      name: map['name'] as String,
      type: map['type'] as String,
      breed: map['breed'] as String?,
      gender: map['gender'] as String?,
      birthDate: map['birth_date'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      color: map['color'] as String?,
      imagePath: map['image_path'] as String?,
      microchip: map['microchip'] as String?,
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'طبيعي',
      archived: (map['archived'] as int?) == 1,
      showerCount: (map['shower_count'] as int?) ?? 0,
    );
  }

  Pet copyWith({
    String? name,
    String? type,
    String? breed,
    String? gender,
    String? birthDate,
    double? weight,
    String? color,
    String? imagePath,
    String? microchip,
    String? notes,
    String? status,
    bool? archived,
    int? showerCount,
  }) {
    return Pet(
      id: id,
      clientId: clientId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      microchip: microchip ?? this.microchip,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      archived: archived ?? this.archived,
      showerCount: showerCount ?? this.showerCount,
    );
  }
}
