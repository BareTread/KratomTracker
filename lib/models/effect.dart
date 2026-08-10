import '_coerce.dart';

class Effect {
  final String id;
  final String dosageId;
  final DateTime timestamp;
  final int mood;
  final int energy;
  final int painRelief;
  final int? anxiety;
  final int? focus;
  final String? notes;
  final Duration? duration;

  const Effect({
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

  Effect copyWith({
    String? id,
    String? dosageId,
    DateTime? timestamp,
    int? mood,
    int? energy,
    int? painRelief,
    int? anxiety,
    int? focus,
    String? notes,
    Duration? duration,
    bool clearAnxiety = false,
    bool clearFocus = false,
    bool clearNotes = false,
    bool clearDuration = false,
  }) {
    return Effect(
      id: id ?? this.id,
      dosageId: dosageId ?? this.dosageId,
      timestamp: timestamp ?? this.timestamp,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      painRelief: painRelief ?? this.painRelief,
      anxiety: clearAnxiety ? null : anxiety ?? this.anxiety,
      focus: clearFocus ? null : focus ?? this.focus,
      notes: clearNotes ? null : notes ?? this.notes,
      duration: clearDuration ? null : duration ?? this.duration,
    );
  }

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

  factory Effect.fromJson(Map<String, dynamic> json) {
    int? optionalInt(dynamic value) => value == null ? null : asInt(value);

    return Effect(
      id: asString(json['id']),
      dosageId: asString(json['dosageId']),
      timestamp: DateTime.tryParse(asString(json['timestamp'])) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      mood: asInt(json['mood']),
      energy: asInt(json['energy']),
      painRelief: asInt(json['painRelief'] ?? json['pain_relief']),
      anxiety: optionalInt(json['anxiety']),
      focus: optionalInt(json['focus']),
      notes: json['notes'] is String ? json['notes'] as String : null,
      duration: json['duration'] == null
          ? null
          : Duration(minutes: asInt(json['duration'])),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Effect &&
          id == other.id &&
          dosageId == other.dosageId &&
          timestamp == other.timestamp &&
          mood == other.mood &&
          energy == other.energy &&
          painRelief == other.painRelief &&
          anxiety == other.anxiety &&
          focus == other.focus &&
          notes == other.notes &&
          duration == other.duration;

  @override
  int get hashCode => Object.hash(
        id,
        dosageId,
        timestamp,
        mood,
        energy,
        painRelief,
        anxiety,
        focus,
        notes,
        duration,
      );
}

enum EffectMetric {
  energy(key: 'energy', label: 'Energy'),
  mood(key: 'mood', label: 'Mood'),
  painRelief(key: 'painRelief', label: 'Pain relief'),
  focus(key: 'focus', label: 'Focus'),
  anxiety(key: 'anxiety', label: 'Calm');

  const EffectMetric({required this.key, required this.label});

  final String key;
  final String label;

  int? valueOf(Effect effect) {
    return switch (this) {
      EffectMetric.energy => effect.energy,
      EffectMetric.mood => effect.mood,
      EffectMetric.painRelief => effect.painRelief,
      EffectMetric.focus => effect.focus,
      EffectMetric.anxiety => effect.anxiety,
    };
  }
}
