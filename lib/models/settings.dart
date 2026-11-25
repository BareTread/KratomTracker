import '_coerce.dart';

class UserSettings {
  final double dailyLimit;
  final String measurementUnit;
  final bool performanceMode;

  const UserSettings({
    this.dailyLimit = 0,
    this.measurementUnit = 'g',
    this.performanceMode = false,
  });

  UserSettings copyWith({
    double? dailyLimit,
    String? measurementUnit,
    bool? performanceMode,
  }) {
    return UserSettings(
      dailyLimit: dailyLimit ?? this.dailyLimit,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      performanceMode: performanceMode ?? this.performanceMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'dailyLimit': dailyLimit,
        'measurementUnit': measurementUnit,
        'performanceMode': performanceMode,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    // Legacy keys (enableNotifications, reminder times, tolerance tracking)
    // are ignored on read — including malformed values — and never re-emitted.
    // A stored "NaN"/"Infinity" would load fine and then make every later
    // save throw in jsonEncode, so anything not finite and >= 0 reads as 0.
    final limit = asDouble(json['dailyLimit']);
    return UserSettings(
      dailyLimit: limit.isFinite && limit >= 0 ? limit : 0,
      measurementUnit: asString(json['measurementUnit'], fallback: 'g'),
      performanceMode: json['performanceMode'] is bool
          ? json['performanceMode'] as bool
          : false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          dailyLimit == other.dailyLimit &&
          measurementUnit == other.measurementUnit &&
          performanceMode == other.performanceMode;

  @override
  int get hashCode =>
      Object.hash(dailyLimit, measurementUnit, performanceMode);
}
