class Client {
  final int? id;
  final String phone;
  final String name;
  final String? notes;
  final String? createdAt; // yyyy-MM-dd HH:mm
  final double balance;
  final String? civilId; // Civil registry / ID number / residency permit (optional)
  final bool archived;

  Client({
    this.id,
    required this.phone,
    required this.name,
    this.notes,
    this.createdAt,
    this.balance = 0,
    this.civilId,
    this.archived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'notes': notes,
      'created_at': createdAt,
      'balance': balance,
      'civil_id': civilId,
      'archived': archived ? 1 : 0,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      phone: map['phone'] as String,
      name: map['name'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      balance: map['balance'] == null ? 0 : (map['balance'] as num).toDouble(),
      civilId: map['civil_id'] as String?,
      archived: (map['archived'] as int?) == 1,
    );
  }

  Client copyWith({
    int? id,
    String? phone,
    String? name,
    String? notes,
    String? createdAt,
    double? balance,
    String? civilId,
    bool? archived,
  }) {
    return Client(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      balance: balance ?? this.balance,
      civilId: civilId ?? this.civilId,
      archived: archived ?? this.archived,
    );
  }
}
