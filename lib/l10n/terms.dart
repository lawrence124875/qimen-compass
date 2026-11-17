import '../engine/qimen_types.dart';
import 'app_languages.dart';

/// 奇門術語的顯示：中文介面只顯示中文；其他語言保留中文，加上拼音與一句意譯，
/// 例如「生門 Sheng Men（Gate of Life）」。意譯先只有英文，其他語言補上前退回英文。
/// 盤面標記。
enum ChartMark { kongWang, horse, menPo, jiXing, ruMu }

class QimenTerms {
  QimenTerms._();

  static const _doors = {
    Door.xiu: ('Xiu Men', {'en': 'Gate of Rest'}),
    Door.sheng: ('Sheng Men', {'en': 'Gate of Life'}),
    Door.shang: ('Shang Men', {'en': 'Gate of Harm'}),
    Door.du: ('Du Men', {'en': 'Gate of Closure'}),
    Door.jingScene: ('Jing Men', {'en': 'Gate of Scenery'}),
    Door.si: ('Si Men', {'en': 'Gate of Death'}),
    Door.jing: ('Jing Men', {'en': 'Gate of Fright'}),
    Door.kai: ('Kai Men', {'en': 'Gate of Opening'}),
  };

  static const _stars = {
    Star.peng: ('Tian Peng', {'en': 'Grass Star'}),
    Star.rui: ('Tian Rui', {'en': 'Grain Star'}),
    Star.chong: ('Tian Chong', {'en': 'Impulse Star'}),
    Star.fu: ('Tian Fu', {'en': 'Assistant Star'}),
    Star.qin: ('Tian Qin', {'en': 'Bird Star'}),
    Star.xin: ('Tian Xin', {'en': 'Heart Star'}),
    Star.zhu: ('Tian Zhu', {'en': 'Pillar Star'}),
    Star.ren: ('Tian Ren', {'en': 'Duty Star'}),
    Star.ying: ('Tian Ying', {'en': 'Hero Star'}),
  };

  static const _gods = {
    God.zhiFu: ('Zhi Fu', {'en': 'Chief'}),
    God.tengShe: ('Teng She', {'en': 'Soaring Serpent'}),
    God.taiYin: ('Tai Yin', {'en': 'Great Moon'}),
    God.liuHe: ('Liu He', {'en': 'Six Harmony'}),
    God.baiHu: ('Bai Hu', {'en': 'White Tiger'}),
    God.xuanWu: ('Xuan Wu', {'en': 'Black Tortoise'}),
    God.jiuDi: ('Jiu Di', {'en': 'Nine Earth'}),
    God.jiuTian: ('Jiu Tian', {'en': 'Nine Heaven'}),
  };

  static const _palaces = {
    1: ('Kan', {'en': 'North'}),
    2: ('Kun', {'en': 'Southwest'}),
    3: ('Zhen', {'en': 'East'}),
    4: ('Xun', {'en': 'Southeast'}),
    5: ('Zhong', {'en': 'Center'}),
    6: ('Qian', {'en': 'Northwest'}),
    7: ('Dui', {'en': 'West'}),
    8: ('Gen', {'en': 'Northeast'}),
    9: ('Li', {'en': 'South'}),
  };

  static const _marks = {
    ChartMark.kongWang: ('空亡', 'Kong Wang', {'en': 'Void'}),
    ChartMark.horse: ('馬星', 'Ma Xing', {'en': 'Horse Star'}),
    ChartMark.menPo: ('門迫', 'Men Po', {'en': 'Gate Pressured'}),
    ChartMark.jiXing: ('擊刑', 'Ji Xing', {'en': 'Punishment'}),
    ChartMark.ruMu: ('入墓', 'Ru Mu', {'en': 'Entering Tomb'}),
  };

  static String door(Door d, AppLanguage lang) => _fmt(d.zh, _doors[d]!, lang);
  static String star(Star s, AppLanguage lang) => _fmt(s.zh, _stars[s]!, lang);
  static String god(God g, AppLanguage lang) => _fmt(g.zh, _gods[g]!, lang);

  /// 宮名，例如「坎宮」或「坎宮 Kan（North）」。
  static String palace(int p, AppLanguage lang) => _fmt('${palaceNames[p]}宮', _palaces[p]!, lang);

  static String mark(ChartMark m, AppLanguage lang) {
    final t = _marks[m]!;
    return _fmt(t.$1, (t.$2, t.$3), lang);
  }

  /// 盤面格內用的單字標記（空、馬、迫、刑、墓），各語言一律中文。
  static String markShort(ChartMark m) => const {
        ChartMark.kongWang: '空', ChartMark.horse: '馬', ChartMark.menPo: '迫', ChartMark.jiXing: '刑', ChartMark.ruMu: '墓', //
      }[m]!;

  static String _fmt(String zh, (String, Map<String, String>) t, AppLanguage lang) {
    if (lang.code.startsWith('zh')) return zh;
    final gloss = t.$2[lang.code] ?? t.$2['en']!;
    return '$zh ${t.$1}（$gloss）';
  }
}
