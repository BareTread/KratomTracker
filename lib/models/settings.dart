import 'package:flutter/material.dart';

import '_coerce.dart';

class UserSettings {
  final bool enableNotifications;
  final TimeOfDay? morningReminder;
  final TimeOfDay? eveningReminder;
  final double dailyLimit;
  final bool enableToleranceTracking;
  final int toleranceBreakInterval;
  final String measurementUnit;
  final bool performanceMode;

  const UserSettings({
    this.enableNotifications = true,
    this.morningReminder,
    this.eveningReminder,
    this.dailyLimit = 0,
    this.enableToleranceTracking = false,
    this.toleranceBreakInterval = 30,
    this.measurementUnit = 'g',
    this.performanceMode = false,
  });

  UserSettings copyWith({
    bool? enableNotifications,
    TimeOfDay? morningReminder,
    TimeOfDay? eveningReminder,
    double? dailyLimit,
    bool? enableToleranceTracking,
    int? toleranceBreakInterval,
    String? measurementUnit,
    bool? performanceMode,
    bool clearMorningReminder = false,
    bool clearEveningReminder = false,
  }) {
    return UserSettings(
      enableNotifications: enableNotifications ?? this.enableNotifications,
      morningReminder:
          clearMorningReminder ? null : morningReminder ?? this.morningReminder,
      eveningReminder:
          clearEveningReminder ? null : eveningReminder ?? this.eveningReminder,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      enableToleranceTracking:
          enableToleranceTracking ?? this.enableToleranceTracking,
      toleranceBreakInterval:
          toleranceBreakInterval ?? this.toleranceBreakInterval,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      performanceMode: performanceMode ?? this.performanceMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'enableNotifications': enableNotifications,
        'morningReminder': morningReminder?.hour,
        'morningReminderMinute': morningReminder?.minute,
        'eveningReminder': eveningReminder?.hour,
        'eveningReminderMinute': eveningReminder?.minute,
        'dailyLimit': dailyLimit,
        'enableToleranceTracking': enableToleranceTracking,
        'toleranceBreakInterval': toleranceBreakInterval,
        'measurementUnit': measurementUnit,
        'performanceMode': performanceMode,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminder(String hourKey, String minuteKey) {
      if (json[hourKey] == null) return null;
      final hour = asInt(json[hourKey], fallback: -1);
      final minute = asInt(json[minuteKey], fallback: -1);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return UserSettings(
      enableNotifications: json['enableNotifications'] is bool
          ? json['enableNotifications'] as bool
          : true,
      morningReminder: reminder('morningReminder', 'morningReminderMinute'),
      eveningReminder: reminder('eveningReminder', 'eveningReminderMinute'),
      dailyLimit: asDouble(json['dailyLimit']),
      enableToleranceTracking: json['enableToleranceTracking'] is bool
          ? json['enableToleranceTracking'] as bool
          : false,
      toleranceBreakInterval:
          asInt(json['toleranceBreakInterval'], fallback: 30),
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
          enableNotifications == other.enableNotifications &&
          morningReminder == other.morningReminder &&
          eveningReminder == other.eveningReminder &&
          dailyLimit == other.dailyLimit &&
          enableToleranceTracking == other.enableToleranceTracking &&
          toleranceBreakInterval == other.toleranceBreakInterval &&
          measurementUnit == other.measurementUnit &&
          performanceMode == other.performanceMode;

  @override
  int get hashCode => Object.hash(
        enableNotifications,
        morningReminder,
        eveningReminder,
        dailyLimit,
        enableToleranceTracking,
        toleranceBreakInterval,
        measurementUnit,
        performanceMode,
      );
}
