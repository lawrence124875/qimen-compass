import 'qimen_types.dart';

/// 一宮之內的格局與九星吉凶（擇時、出行、問事共用）。
///
/// 天干索引：甲0 乙1 丙2 丁3 戊4 己5 庚6 辛7 壬8 癸9。
enum GeJu {
  /// 九星吉：天輔、天禽、天心同宮。
  goodStar(true),

  /// 三遁：天遁（生門＋天盤丙加地盤丁）、地遁（開門＋天盤乙加地盤己）、人遁（休門＋天盤丁＋太陰）。
  sanDun(true),

  /// 九星凶：天蓬、天芮同宮。
  badStar(false),

  /// 四凶格：青龍逃走（乙加辛）、白虎猖狂（辛加乙）、朱雀投江（丁加癸）、螣蛇夭矯（癸加丁）。
  siXiong(false),

  /// 庚丙相加：太白入熒（庚加丙）、熒入太白（丙加庚）。
  gengBing(false);

  const GeJu(this.good);
  final bool good;
}

const _goodStars = {Star.fu, Star.qin, Star.xin};
const _badStars = {Star.peng, Star.rui};

/// 天盤 [h] 加地盤 [e]。
bool _on(PalaceChart c, int h, int e) => c.heavenStems.contains(h) && c.earthStems.contains(e);

/// 九星吉凶（吉星凶星同宮時相抵，都不列）。
GeJu? starLuck(PalaceChart c) {
  final good = c.stars.any(_goodStars.contains);
  final bad = c.stars.any(_badStars.contains);
  if (good == bad) return null;
  return good ? GeJu.goodStar : GeJu.badStar;
}

/// 一宮的干格（不含九星）。
List<GeJu> stemPatterns(PalaceChart c) => [
      if ((c.door == Door.sheng && _on(c, 2, 3)) ||
          (c.door == Door.kai && _on(c, 1, 5)) ||
          (c.door == Door.xiu && c.heavenStems.contains(3) && c.god == God.taiYin))
        GeJu.sanDun,
      if (_on(c, 1, 7) || _on(c, 7, 1) || _on(c, 3, 9) || _on(c, 9, 3)) GeJu.siXiong,
      if (_on(c, 6, 2) || _on(c, 2, 6)) GeJu.gengBing,
    ];

/// 一宮的格局與九星吉凶。
List<GeJu> geJuOf(PalaceChart c) => [
      if (starLuck(c) case final s?) s,
      ...stemPatterns(c),
    ];
