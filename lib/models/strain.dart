class Strain {
  final String id;
  final String name;
  final String code;
  final int color;

  Strain({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'color': color,
    };
  }

  factory Strain.fromJson(Map<String, dynamic> json) {
    return Strain(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      color: json['color'],
    );
  }
} 