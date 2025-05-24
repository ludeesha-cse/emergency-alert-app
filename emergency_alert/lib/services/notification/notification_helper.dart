import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../utils/constants.dart';

/// A helper class to handle notification channel creation and initialization
class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationHelper() => _instance;

  NotificationHelper._internal();

  /// Initialize the notification channels and settings
  Future<void> initialize() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    // InitializationSettings for both platforms
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await _createNotificationChannels();
  }

  /// Create required notification channels
  Future<void> _createNotificationChannels() async {
    // Create the background service notification channel
    AndroidNotificationChannel backgroundServiceChannel =
        AndroidNotificationChannel(
          AppConstants.backgroundServiceNotificationChannelId,
          AppConstants.backgroundServiceNotificationChannelName,
          importance: Importance.low,
          showBadge: false,
          playSound: false,
          description:
              'Used for keeping the emergency monitoring service active',
        );

    // Create emergency alert notification channel
    AndroidNotificationChannel emergencyAlertChannel =
        AndroidNotificationChannel(
          'emergency_alerts',
          'Emergency Alerts',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          description:
              'Critical emergency alerts that require immediate attention',
        );

    // Register the channels with the system
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(backgroundServiceChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(emergencyAlertChannel);
  }

  /// Show a notification for the foreground service
  Future<void> showForegroundServiceNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.backgroundServiceNotificationChannelId,
          AppConstants.backgroundServiceNotificationChannelName,
          channelShowBadge: false,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: 'ic_bg_service_small',
        ),
      ),
    );
  }

  /// Update the foreground service notification
  Future<void> updateForegroundServiceNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await showForegroundServiceNotification(id: id, title: title, body: body);
  }
}
