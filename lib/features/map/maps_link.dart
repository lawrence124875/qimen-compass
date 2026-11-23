import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/notifications.dart';
import 'address_search.dart';
import 'map_page.dart';

/// Google 地圖分享連結／文字 → 地點（免費，不用 Places API）。
/// 支援 maps.app.goo.gl 短網址（追轉址）、google.*/maps/place/…/@lat,lng、!3d…!4d…、?q=lat,lng，以及直接的「lat, lng」。
class MapsLink {
  MapsLink._();

  static final _url = RegExp(
      r'https?://(?:maps\.app\.goo\.gl|goo\.gl/maps|(?:www\.)?google\.[a-z.]+/maps|maps\.google\.[a-z.]+)[^\s<>"]*',
      caseSensitive: false);
  static final _latLng = RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})');

  /// 文字裡有 Google 地圖連結或座標就回傳 true。
  static bool looksLikeLink(String text) => _url.hasMatch(text) || _bareLatLng(text) != null;

  static (double, double)? _bareLatLng(String text) {
    if (_url.hasMatch(text)) return null;
    final m = _latLng.firstMatch(text);
    return m == null ? null : _valid(double.parse(m[1]!), double.parse(m[2]!));
  }

  static (double, double)? _valid(double la, double lo) => la.abs() <= 90 && lo.abs() <= 180 ? (la, lo) : null;

  /// 從網址取座標：優先地點本身（!3d!4d），其次 q／ll 參數，最後鏡頭中心（@）。
  static (double, double)? coordsInUrl(String url) {
    final u = Uri.decodeFull(url);
    for (final re in [
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'[?&](?:q|ll|query|destination|center)=(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
    ]) {
      final m = re.firstMatch(u);
      if (m != null) return _valid(double.parse(m[1]!), double.parse(m[2]!));
    }
    return null;
  }

  static String? nameInUrl(String url) {
    final m = RegExp(r'/maps/place/([^/@?]+)').firstMatch(url);
    if (m == null) return null;
    final n = Uri.decodeComponent(m[1]!.replaceAll('+', ' ')).trim();
    return n.isEmpty ? null : n;
  }

  /// 分享文字的第一行（不是網址時）通常是地點名稱。
  static String? _nameInText(String text) {
    for (final line in text.split('\n')) {
      final s = line.trim();
      if (s.isNotEmpty && !_url.hasMatch(s)) return s.length > 60 ? s.substring(0, 60) : s;
    }
    return null;
  }

  /// 解析分享文字或連結；找不到座標回傳 null。
  static Future<Place?> resolve(String text) async {
    final bare = _bareLatLng(text);
    if (bare != null) return Place(bare.$1, bare.$2, _nameInText(text.replaceAll(_latLng, '')) ?? '${bare.$1}, ${bare.$2}');
    final m = _url.firstMatch(text);
    if (m == null) return null;
    var url = m[0]!;
    var c = coordsInUrl(url);
    if (c == null) {
      final r = await _follow(url);
      if (r != null) {
        url = r.$1;
        c = coordsInUrl(url) ?? r.$2;
      }
    }
    if (c == null) return null;
    return Place(c.$1, c.$2, nameInUrl(url) ?? _nameInText(text) ?? '${c.$1.toStringAsFixed(5)}, ${c.$2.toStringAsFixed(5)}');
  }

  /// 追短網址轉址，回傳最後網址；網址沒座標時從頁面內容找（部分轉址頁把座標放在內文）。
  static Future<(String, (double, double)?)?> _follow(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      var uri = Uri.parse(url);
      for (var i = 0; i < 6; i++) {
        final req = await client.getUrl(uri);
        req.followRedirects = false;
        req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Linux; Android 14) QimenCompass');
        final res = await req.close().timeout(const Duration(seconds: 10));
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (res.isRedirect && loc != null) {
          await res.drain<void>();
          uri = uri.resolve(loc);
          if (coordsInUrl(uri.toString()) != null) return (uri.toString(), null);
          continue;
        }
        final body = await res.transform(const Utf8Decoder(allowMalformed: true)).take(64).join().timeout(const Duration(seconds: 10));
        final m = RegExp(r'(?:center=|@|!3d)(-?\d+\.\d{4,})(?:%2C|,|!4d)(-?\d+\.\d{4,})').firstMatch(body);
        return (uri.toString(), m == null ? null : _valid(double.parse(m[1]!), double.parse(m[2]!)));
      }
      return (uri.toString(), null);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Android：從 Google 地圖「分享」到奇門羅盤（原生 `android_extra/kotlin/MainActivity.kt`，頻道 `qm/share`）。
/// 收到後開羅盤地圖並標出該地點。iOS 沒有分享入口，改用「複製連結→貼上」。
class SharedPlaceInbox {
  SharedPlaceInbox._();

  static const _channel = MethodChannel('qm/share');

  static void start() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) _open(call.arguments as String);
    });
    _channel.invokeMethod<String>('initial').then((t) {
      if (t != null && t.isNotEmpty) _open(t);
    }).catchError((_) {});
  }

  static Future<void> _open(String text) async {
    for (var i = 0; i < 20; i++) {
      final nav = Notifications.navigatorKey.currentState;
      if (nav != null) {
        await nav.push(MaterialPageRoute<void>(builder: (_) => MapPage(sharedText: text)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
}
