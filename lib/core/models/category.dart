class Category {
  final String id;
  final String name;
  final String description;
  final int slabCount;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.slabCount,
  });

  @override
  String toString() => 'Category($name)';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'slabCount': slabCount,
  };

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      slabCount: (json['slabCount'] as num?)?.toInt() ?? 0,
    );
  }
}
