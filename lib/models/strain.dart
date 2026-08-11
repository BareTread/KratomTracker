import '_coerce.dart';
import '../widgets/strain_mark.dart';

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
    final code = asString(json['code']);
    // Absent or null → true, so legacy payloads stay fully in stock. A
    // present-but-garbage value also falls back to true rather than silently
    // marking a strain out of stock.
    final stockRaw = json['inStock'];
    return Strain(
      id: asString(json['id']),
      name: asString(json['name']),
      code: code,
      color: asInt(json['color']),
      // Normalise to a LeafShape.name on read: legacy Material icon names map
      // to their shape, and anything unrecognised falls back to a shape
      // derived deterministically from the strain's code. A missing field is
      // covered by the same deterministic fallback rather than a fixed
      // default, so a 30-strain library doesn't collapse onto one shape.
      icon: resolveLeafShape(asString(json['icon']), code).name,
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
