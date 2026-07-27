class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.nip,
  });
  final String id;
  final String fullName;
  final String role;
  final String? nip;

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    fullName: map['full_name'] as String,
    role: map['role'] as String,
    nip: map['nip'] as String?,
  );
}
