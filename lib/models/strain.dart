class Strain {
  final String id;
  final String name;
  final String code;
  final int color;
  final String icon;

  const Strain({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'color': color,
      'icon': icon,
    };
  }

  factory Strain.fromJson(Map<String, dynamic> json) {
    return Strain(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      color: json['color'],
      icon: json['icon'],
    );
  }
} 