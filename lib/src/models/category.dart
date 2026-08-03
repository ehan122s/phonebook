class Category {
  const Category({required this.id, required this.name, this.description});
  final String id;
  final String name;
  final String? description;
  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
  );
}
