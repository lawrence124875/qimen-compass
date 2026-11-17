import 'package:flutter/foundation.dart';

/// 對外連結（比照謙卦）。隱私權政策、服務條款放本 repo docs/（GitHub Pages）。
const privacyPolicyUrl = 'https://lawrence124875.github.io/qimen-compass/privacy.html';
const termsOfServiceUrl = 'https://lawrence124875.github.io/qimen-compass/terms.html';

/// 分享文字附上的下載連結：Android 為 Google Play；iOS 上架後由 CI 傳入 App Store 網址（IOS_STORE_URL）。
const _playUrl = 'https://play.google.com/store/apps/details?id=com.lclab.qimen';
const _iosUrl = String.fromEnvironment('IOS_STORE_URL');
String get storeUrl => defaultTargetPlatform == TargetPlatform.iOS && _iosUrl.isNotEmpty ? _iosUrl : _playUrl;

/// 設定頁「LC Lab 其他 App」。圖示在 assets/other_apps/（不連網抓），以外部應用程式開 Play 商店頁，不加追蹤參數。
class OtherApp {
  const OtherApp({required this.id, required this.icon});

  /// Play 套件名稱。
  final String id;
  final String icon;

  String get url => 'https://play.google.com/store/apps/details?id=$id';
}

const otherAppQiangua = OtherApp(id: 'com.lclab.qiangua', icon: 'assets/other_apps/qiangua.png');
const otherAppTarot = OtherApp(id: 'com.lclab.tarot', icon: 'assets/other_apps/tarot.png');
