import '_coerce.dart';

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

  Strain copyWith({
    String? id,
    String? name,
    String? code,
    int? color,
    String? icon,
  }) {
    return Strain(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'color': color,
        'icon': icon,
      };

  factory Strain.fromJson(Map<String, dynamic> json) {
    return Strain(
      id: asString(json['id']),
      name: asString(json['name']),
      code: asString(json['code']),
      color: asInt(json['color']),
      icon: asString(json['icon'], fallback: 'Leaf'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Strain &&
          id == other.id &&
          name == other.name &&
          code == other.code &&
          color == other.color &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(id, name, code, color, icon);
}
