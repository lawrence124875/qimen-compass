import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/features/map/maps_link.dart';

void main() {
  test('Google 地圖連結取座標與名稱', () {
    const place = 'https://www.google.com/maps/place/%E5%8F%B0%E5%8C%97101/@25.0339639,121.5644722,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d25.0339687!4d121.5645389';
    expect(MapsLink.coordsInUrl(place), (25.0339687, 121.5645389));
    expect(MapsLink.nameInUrl(place), '台北101');
    expect(MapsLink.coordsInUrl('https://maps.google.com/?q=35.6586,139.7454'), (35.6586, 139.7454));
    expect(MapsLink.coordsInUrl('https://www.google.com/maps/@-33.8568,151.2153,15z'), (-33.8568, 151.2153));
    expect(MapsLink.looksLikeLink('台北101\nhttps://maps.app.goo.gl/abc123'), isTrue);
    expect(MapsLink.looksLikeLink('25.0339, 121.5645'), isTrue);
    expect(MapsLink.looksLikeLink('台北市信義路五段7號'), isFalse);
  });

  test('直接貼座標不用連網', () async {
    final p = await MapsLink.resolve('25.0339, 121.5645');
    expect(p?.lat, 25.0339);
    expect(p?.lon, 121.5645);
  });
}
