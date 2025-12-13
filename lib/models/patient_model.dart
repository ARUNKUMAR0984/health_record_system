class Patient {
  final String id;        // Unique patient ID (UUID)
  final String userId;    // Supabase auth.users ID
  final String name;
  final int age;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.userId,
    required this.name,
    required this.age,
    required this.createdAt,
  });

  // Convert Supabase row -> Patient object
  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      age: map['age'] is int ? map['age'] as int : int.parse(map['age'].toString()),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Convert Patient object -> Map (for inserting/updating)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'age': age,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
