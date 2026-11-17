import '../engine/qimen_types.dart';
import 'app_languages.dart';

/// 奇門術語的顯示：中文介面只顯示中文；其他語言保留中文，加上拼音與一句意譯，
/// 例如「生門 Sheng Men（Gate of Life）」。意譯先只有英文，其他語言補上前退回英文。
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

  static String door(Door d, AppLanguage lang) => _fmt(d.zh, _doors[d]!, lang);
  static String star(Star s, AppLanguage lang) => _fmt(s.zh, _stars[s]!, lang);
  static String god(God g, AppLanguage lang) => _fmt(g.zh, _gods[g]!, lang);

  static String _fmt(String zh, (String, Map<String, String>) t, AppLanguage lang) {
    if (lang.code.startsWith('zh')) return zh;
    final gloss = t.$2[lang.code] ?? t.$2['en']!;
    return '$zh ${t.$1}（$gloss）';
  }
}
