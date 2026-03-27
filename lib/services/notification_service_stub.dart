// Stub implementation for non-web platforms
import 'dart:async';
import 'notification_service.dart';

bool platformIsSupported() => false;

Future<NotificationPermission> platformRequestPermission() async =>
    NotificationPermission.denied;

Future<NotificationPermission> platformCheckPermission() async =>
    NotificationPermission.denied;

void platformShowNotification({
  required String title,
  required String body,
  required String icon,
}) {
  // No-op on non-web platforms
}
