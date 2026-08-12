import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// On-device scheduled notifications for payment due-date reminders.
/// No backend/Firebase involved — the OS itself fires the notification at
/// the scheduled local time, so it works even if the phone is offline.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'payment_reminders';
  static const _channelName = 'Payment Reminders';
  static const _channelDescription = 'Reminders to follow up on customer dues';

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // Nepal doesn't observe DST and every business using this app is
    // Nepal-based, so anchoring to Kathmandu (rather than the device's
    // detected zone) keeps reminder times consistent even if a phone's
    // system zone is briefly wrong (common right after travel/roaming).
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Android 13+ requires this to be requested at runtime; returns true if
  /// granted (or already granted / not required on this platform version).
  Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? true;
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? true;
    }
    return true;
  }

  /// Schedules a reminder to fire at [scheduledDate] (local time). [id] must
  /// be a stable, unique identifier for the thing being reminded about — the
  /// Sale id works well, since it also lets [cancel] target the right one.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await init();
    final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }
}
