import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/settings.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to specific screen
  }

  Future<void> requestPermissions() async {
    // Request permissions for iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleReminders(UserSettings settings) async {
    if (!_initialized) await initialize();

    // Cancel existing reminders
    await cancelAllReminders();

    if (!settings.enableNotifications) return;

    // Schedule morning reminder
    if (settings.morningReminder != null) {
      await _scheduleDailyNotification(
        id: 1,
        title: '🌅 Morning Check-in',
        body: 'Time to track your dosage and plan your day',
        time: settings.morningReminder!,
      );
    }

    // Schedule evening reminder
    if (settings.eveningReminder != null) {
      await _scheduleDailyNotification(
        id: 2,
        title: '🌙 Evening Check-in',
        body: 'Don\'t forget to log your dosages for today',
        time: settings.eveningReminder!,
      );
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the scheduled time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily Reminders',
          channelDescription: 'Reminders to track your dosages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showDailyLimitWarning(double current, double limit) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      100,
      '⚠️ Daily Limit Approaching',
      'You\'ve consumed ${current.toStringAsFixed(1)}g of your ${limit.toStringAsFixed(1)}g daily limit',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'warnings',
          'Warnings',
          channelDescription: 'Important warnings and alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showDailyLimitExceeded(double current, double limit) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      101,
      '🛑 Daily Limit Exceeded',
      'You\'ve exceeded your daily limit: ${current.toStringAsFixed(1)}g / ${limit.toStringAsFixed(1)}g',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'warnings',
          'Warnings',
          channelDescription: 'Important warnings and alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Colors.red,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showToleranceBreakReminder(int daysUsed, int breakInterval) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      102,
      '🔄 Tolerance Break Recommended',
      'You\'ve used kratom for $daysUsed consecutive days. Consider a break (recommended every $breakInterval days)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tolerance',
          'Tolerance Tracking',
          channelDescription: 'Tolerance break reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showDuplicateWarning() async {
    if (!_initialized) await initialize();

    await _notifications.show(
      103,
      '⚡ Duplicate Dosage Detected',
      'You logged a dosage recently. Please verify this isn\'t a duplicate entry.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'warnings',
          'Warnings',
          channelDescription: 'Important warnings and alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancel(1); // Morning
    await _notifications.cancel(2); // Evening
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
