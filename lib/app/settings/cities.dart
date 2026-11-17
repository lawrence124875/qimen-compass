/// 真太陽時用的城市經度（比照謙卦：讓使用者選城市，不取位置權限）。
class City {
  const City(this.zh, this.en, this.longitude);
  final String zh, en;
  final double longitude;

  String name(String langCode) => langCode.startsWith('zh') ? zh : en;
}

const List<City> kCities = [
  City('台北', 'Taipei', 121.56),
  City('新竹', 'Hsinchu', 120.97),
  City('台中', 'Taichung', 120.68),
  City('台南', 'Tainan', 120.21),
  City('高雄', 'Kaohsiung', 120.31),
  City('花蓮', 'Hualien', 121.60),
  City('香港', 'Hong Kong', 114.17),
  City('澳門', 'Macau', 113.54),
  City('北京', 'Beijing', 116.40),
  City('上海', 'Shanghai', 121.47),
  City('廣州', 'Guangzhou', 113.26),
  City('成都', 'Chengdu', 104.07),
  City('新加坡', 'Singapore', 103.82),
  City('吉隆坡', 'Kuala Lumpur', 101.69),
  City('曼谷', 'Bangkok', 100.50),
  City('東京', 'Tokyo', 139.69),
  City('首爾', 'Seoul', 126.98),
  City('雪梨', 'Sydney', 151.21),
  City('倫敦', 'London', -0.13),
  City('紐約', 'New York', -74.01),
  City('洛杉磯', 'Los Angeles', -118.24),
  City('溫哥華', 'Vancouver', -123.12),
];
