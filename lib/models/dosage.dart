import '_coerce.dart';

class Dosage {
  final String id;
  final String strainId;
  final double amount;
  final DateTime timestamp;
  final String? notes;

  const Dosage({
    required this.id,
    required this.strainId,
    required this.amount,
    required this.timestamp,
    this.notes,
  });

  Dosage copyWith({
    String? id,
    String? strainId,
    double? amount,
    DateTime? timestamp,
    String? notes,
    bool clearNotes = false,
  }) {
    return Dosage(
      id: id ?? this.id,
      strainId: strainId ?? this.strainId,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'strainId': strainId,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
        'notes': notes,
      };

  factory Dosage.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse(asString(json['timestamp']));
    if (timestamp == null) {
      throw const FormatException('Invalid dosage timestamp');
    }
    return Dosage(
      id: asString(json['id']),
      strainId: asString(json['strainId']),
      amount: asDouble(json['amount']),
      timestamp: timestamp,
      notes: json['notes'] is String ? json['notes'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dosage &&
          id == other.id &&
          strainId == other.strainId &&
          amount == other.amount &&
          timestamp == other.timestamp &&
          notes == other.notes;

  @override
  int get hashCode => Object.hash(id, strainId, amount, timestamp, notes);
}
