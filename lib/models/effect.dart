class Effect {
  final String id;
  final String dosageId;
  final DateTime timestamp;
  final int mood; // 1-5 scale
  final int energy; // 1-5 scale
  final int painRelief; // 1-5 scale
  final int? anxiety; // 1-5 scale, optional
  final int? focus; // 1-5 scale, optional
  final String? notes;
  final Duration? duration; // How long effects lasted

  Effect({
    required this.id,
    required this.dosageId,
    required this.timestamp,
    required this.mood,
    required this.energy,
    required this.painRelief,
    this.anxiety,
    this.focus,
    this.notes,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dosageId': dosageId,
        'timestamp': timestamp.toIso8601String(),
        'mood': mood,
        'energy': energy,
        'painRelief': painRelief,
        'anxiety': anxiety,
        'focus': focus,
        'notes': notes,
        'duration': duration?.inMinutes,
      };

  factory Effect.fromJson(Map<String, dynamic> json) => Effect(
        id: json['id'],
        dosageId: json['dosageId'],
        timestamp: DateTime.parse(json['timestamp']),
        mood: json['mood'],
        energy: json['energy'],
        painRelief: json['painRelief'],
        anxiety: json['anxiety'],
        focus: json['focus'],
        notes: json['notes'],
        duration: json['duration'] != null
            ? Duration(minutes: json['duration'])
            : null,
      );
} 