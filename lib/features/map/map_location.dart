import 'package:geolocator/geolocator.dart';

/// 地圖用的目前位置（精確度中等；使用者在 Android 12+ 可選只給概略位置）。失敗回傳 null。
Future<(double, double)?> currentLatLon() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
        ).catchError((_) async => (await Geolocator.getLastKnownPosition())!);
    return (pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// 距離文字：1 公里以下用公尺。
String distanceText(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
