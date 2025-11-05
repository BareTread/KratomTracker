class Dosage {
  final String id;
  final String strainId;
  final double amount;
  final DateTime timestamp;
  final String? notes;
  final List<String> tags;

  Dosage({
    required this.id,
    required this.strainId,
    required this.amount,
    required this.timestamp,
    this.notes,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'strainId': strainId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'tags': tags,
    };
  }

  factory Dosage.fromJson(Map<String, dynamic> json) {
    return Dosage(
      id: json['id'],
      strainId: json['strainId'],
      amount: json['amount'],
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
    );
  }

  // Common tags
  static const List<String> commonTags = [
    'With Food',
    'Empty Stomach',
    'Morning',
    'Evening',
    'Work',
    'Relaxation',
    'Exercise',
    'Social',
    'Pain Management',
    'Focus',
  ];
} 