import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../theme/app_theme.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> sendWarning({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'waqfa_channel',
          'وقفة',
          channelDescription: 'تنبيهات مالية',
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.primary,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> scheduleMonthlyReminder() async {
    await _plugin.zonedSchedule(
      1,
      '⏰ حان وقت مراجعة وضعك المالي',
      'شهر جديد — حلّل راتبك وأقساطك مع وقفة',
      _nextMonthStart(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'waqfa_monthly',
          'تذكير شهري',
          channelDescription: 'تذكير شهري بمراجعة الوضع المالي',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  static tz.TZDateTime _nextMonthStart() {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month + 1, 1, 9, 0);
  }
}
