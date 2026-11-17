import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 本機通知（比照謙卦）：
/// - 不請求精確鬧鐘權限（`SCHEDULE_EXACT_ALARM`），一律 `inexactAllowWhileIdle`；
/// - 啟動時不要求通知權限，由功能在使用者第一次看到結果時呼叫 [requestPermission]；
/// - Android 端的兩個 receiver、desugaring、ProGuard 規則由 `scripts/patch_android.sh` 加上。
class Notifications {
  Notifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// App 的 Navigator（點通知開對應頁面用；在 MaterialApp 設定）。
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// payload → 頁面（由 main 註冊，避免 services 依賴功能模組）。
  static final Map<String, Route<void> Function()> routes = {};

  static void _open(String? payload) {
    final builder = routes[payload];
    final nav = navigatorKey.currentState;
    if (builder == null || nav == null) return;
    nav.push(builder());
  }

  /// App 由通知啟動時，開啟對應頁面（第一個畫面出現後呼叫）。
  static Future<void> handleLaunch() async {
    await init();
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) _open(d!.notificationResponse?.payload);
  }
  static Future<void>? _init;

  static Future<void> init() => _init ??= _doInit();

  static Future<void> _doInit() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: (r) => _open(r.payload));
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  /// 請求通知權限；回傳是否允許。
  static Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) return await _android?.requestNotificationsPermission() ?? false;
    if (Platform.isIOS) return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return false;
  }

  /// 通知是否已允許（iOS 無法查詢時視為允許）。
  static Future<bool> enabled() async {
    await init();
    if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? false;
    return true;
  }

  /// 在 [atUtc] 跳出通知（非精確，系統可能延後數分鐘）。
  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime atUtc,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(atUtc.toUtc(), tz.UTC),
      NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName,
            importance: Importance.high, priority: Priority.high, styleInformation: BigTextStyleInformation(body)),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// 取消 id 在 [from]–[to]（含）之間、已排程的通知。
  static Future<void> cancelRange(int from, int to) async {
    await init();
    for (final r in await _plugin.pendingNotificationRequests()) {
      if (r.id >= from && r.id <= to) await _plugin.cancel(r.id);
    }
  }
}
