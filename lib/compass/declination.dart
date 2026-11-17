import 'package:geolocator/geolocator.dart';
import 'package:geomag/geomag.dart';

/// 磁偏角（WMM 2025，`geomag`）：東偏為正。真北方位角＝磁北方位角＋磁偏角。
class Declination {
  Declination._();

  static double at(double lat, double lon, [DateTime? date]) =>
      GeoMag().calculate(lat, lon, 0, date ?? DateTime.now()).dec;

  /// 取大概位置（只要求「概略位置」權限，不要求精確位置）算磁偏角；被拒或失敗回傳 null。
  static Future<DeclinationResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const DeclinationResult.failed(DeclinationError.serviceOff);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return const DeclinationResult.failed(DeclinationError.denied);
      }
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
          );
      return DeclinationResult(at(pos.latitude, pos.longitude));
    } catch (_) {
      return const DeclinationResult.failed(DeclinationError.unavailable);
    }
  }
}

enum DeclinationError { serviceOff, denied, unavailable }

class DeclinationResult {
  const DeclinationResult(double this.degrees) : error = null;
  const DeclinationResult.failed(DeclinationError this.error) : degrees = null;

  final double? degrees;
  final DeclinationError? error;
}
