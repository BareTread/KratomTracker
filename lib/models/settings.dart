import 'package:flutter/material.dart';

class UserSettings {
  final bool enableNotifications;
  final TimeOfDay? morningReminder;
  final TimeOfDay? eveningReminder;
  final double dailyLimit;
  final bool enableToleranceTracking;
  final int toleranceBreakInterval;
  final List<String> trackedEffects;
  final bool darkMode;
  final String measurementUnit;

  UserSettings({
    this.enableNotifications = true,
    this.morningReminder,
    this.eveningReminder,
    this.dailyLimit = 0.0, // 0 means no limit
    this.enableToleranceTracking = false,
    this.toleranceBreakInterval = 30,
    this.trackedEffects = const ['mood', 'energy', 'painRelief'],
    this.darkMode = true,
    this.measurementUnit = 'g',
  });

  Map<String, dynamic> toJson() => {
        'enableNotifications': enableNotifications,
        'morningReminder': morningReminder?.hour,
        'morningReminderMinute': morningReminder?.minute,
        'eveningReminder': eveningReminder?.hour,
        'eveningReminderMinute': eveningReminder?.minute,
        'dailyLimit': dailyLimit,
        'enableToleranceTracking': enableToleranceTracking,
        'toleranceBreakInterval': toleranceBreakInterval,
        'trackedEffects': trackedEffects,
        'darkMode': darkMode,
        'measurementUnit': measurementUnit,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        enableNotifications: json['enableNotifications'] ?? true,
        morningReminder: json['morningReminder'] != null
            ? TimeOfDay(
                hour: json['morningReminder'],
                minute: json['morningReminderMinute'],
              )
            : null,
        eveningReminder: json['eveningReminder'] != null
            ? TimeOfDay(
                hour: json['eveningReminder'],
                minute: json['eveningReminderMinute'],
              )
            : null,
        dailyLimit: json['dailyLimit'] ?? 0.0,
        enableToleranceTracking: json['enableToleranceTracking'] ?? false,
        toleranceBreakInterval: json['toleranceBreakInterval'] ?? 30,
        trackedEffects: List<String>.from(json['trackedEffects'] ??
            ['mood', 'energy', 'painRelief']),
        darkMode: json['darkMode'] ?? true,
        measurementUnit: json['measurementUnit'] ?? 'g',
      );
} 