import '_coerce.dart';

class Strain {
  final String id;
  final String name;
  final String code;
  final int color;
  final String icon;

  /// Whether the owner currently has this strain on hand. Defaults to true so
  /// existing strains and old backups come back in stock after upgrade —
  /// nobody has to re-mark anything.
  final bool inStock;

  const Strain({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.icon,
    this.inStock = true,
  });

  Strain copyWith({
    String? id,
    String? name,
    String? code,
    int? color,
    String? icon,
    bool? inStock,
  }) {
    return Strain(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      inStock: inStock ?? this.inStock,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'color': color,
        'icon': icon,
        'inStock': inStock,
      };

  factory Strain.fromJson(Map<String, dynamic> json) {
    // Absent or null → true, so legacy payloads stay fully in stock. A
    // present-but-garbage value also falls back to true rather than silently
    // marking a strain out of stock.
    final stockRaw = json['inStock'];
    return Strain(
      id: asString(json['id']),
      name: asString(json['name']),
      code: asString(json['code']),
      color: asInt(json['color']),
      icon: asString(json['icon'], fallback: 'Leaf'),
      inStock: stockRaw == null ? true : asBool(stockRaw, fallback: true),
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
          icon == other.icon &&
          inStock == other.inStock;

  @override
  int get hashCode => Object.hash(id, name, code, color, icon, inStock);
}
