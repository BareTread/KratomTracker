class Dosage {
  final String id;
  final String strainId;
  final double amount;
  final DateTime timestamp;
  final String? notes;

  Dosage({
    required this.id,
    required this.strainId,
    required this.amount,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'strainId': strainId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory Dosage.fromJson(Map<String, dynamic> json) {
    return Dosage(
      id: json['id'],
      strainId: json['strainId'],
      amount: json['amount'],
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
    );
  }
} 