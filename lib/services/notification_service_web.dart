// Web-specific notification implementation.
// Uses dart:js_util (built-in for Flutter web) — no extra pub package needed.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
// dart:js_util is available on every Flutter web build without any pub dep.
import 'dart:js_util' as js_util;

import 'notification_service.dart';

/// Returns the JS global object (window).
Object get _globalThis => js_util.globalThis as Object;

bool platformIsSupported() {
  try {
    final notif = js_util.getProperty(_globalThis, 'Notification');
    return notif != null;
  } catch (_) {
    return false;
  }
}

Future<NotificationPermission> platformRequestPermission() async {
  try {
    final notifClass =
        js_util.getProperty(_globalThis, 'Notification') as Object;
    final result = await js_util.promiseToFuture<String>(
      js_util.callMethod(notifClass, 'requestPermission', []) as Object,
    );
    return _parse(result);
  } catch (_) {
    return NotificationPermission.denied;
  }
}

Future<NotificationPermission> platformCheckPermission() async {
  try {
    final notifClass =
        js_util.getProperty(_globalThis, 'Notification') as Object;
    final perm =
        js_util.getProperty(notifClass, 'permission') as String? ?? 'default';
    return _parse(perm);
  } catch (_) {
    return NotificationPermission.denied;
  }
}

void platformShowNotification({
  required String title,
  required String body,
  required String icon,
}) {
  try {
    // Use the helper we injected in index.html
    js_util.callMethod(_globalThis, '_showWebNotification', [title, body, icon]);
  } catch (e) {
    // Direct fallback
    try {
      final notifClass =
          js_util.getProperty(_globalThis, 'Notification') as Object;
      final options = js_util.newObject<Object>();
      js_util.setProperty(options, 'body', body);
      js_util.setProperty(options, 'icon', icon);
      js_util.callConstructor(notifClass, [title, options]);
    } catch (_) {}
  }
}

NotificationPermission _parse(String value) {
  switch (value) {
    case 'granted':
      return NotificationPermission.granted;
    case 'denied':
      return NotificationPermission.denied;
    default:
      return NotificationPermission.defaultState;
  }
}
