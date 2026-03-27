import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional import: web file uses dart:js_util, stub for native/desktop.
import 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_stub.dart';

enum NotificationPermission { granted, denied, defaultState }

class NotificationService extends ChangeNotifier {
  bool _remindersEnabled = false;
  int _intervalMinutes = 30;
  Timer? _reminderTimer;

  bool get remindersEnabled => _remindersEnabled;
  int get intervalMinutes => _intervalMinutes;

  /// True only when running on the web AND the browser supports the
  /// Notification API.
  bool get isSupported => kIsWeb && platformIsSupported();

  Future<NotificationPermission> requestPermission() async {
    if (!isSupported) return NotificationPermission.denied;
    return platformRequestPermission();
  }

  Future<NotificationPermission> checkPermission() async {
    if (!isSupported) return NotificationPermission.denied;
    return platformCheckPermission();
  }

  /// Requests permission and starts the periodic reminder timer.
  /// Returns true when reminders were successfully enabled.
  Future<bool> enableReminders({int intervalMinutes = 30}) async {
    if (!isSupported) return false;
    final permission = await requestPermission();
    if (permission != NotificationPermission.granted) return false;

    _intervalMinutes = intervalMinutes;
    _remindersEnabled = true;
    _startTimer();
    notifyListeners();
    return true;
  }

  void disableReminders() {
    _remindersEnabled = false;
    _reminderTimer?.cancel();
    _reminderTimer = null;
    notifyListeners();
  }

  void _startTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(
      Duration(minutes: _intervalMinutes),
      (_) => _fireReminder(),
    );
  }

  void _fireReminder() {
    if (!_remindersEnabled) return;
    platformShowNotification(
      title: 'Time to Hydrate!',
      body: "Don't forget to drink some water. Stay healthy!",
      icon: '/icons/Icon-192.png',
    );
  }

  /// Sends a one-off test notification so the user can verify setup.
  void sendTestNotification() {
    platformShowNotification(
      title: 'Water Manager',
      body:
          "Notifications are working! You'll be reminded every $_intervalMinutes minutes.",
      icon: '/icons/Icon-192.png',
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }
}
