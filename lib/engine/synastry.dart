import 'calendar_service.dart';
import 'chuxing.dart';
import 'divination.dart';
import 'ganzhi.dart';
import 'personal.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';
import 'zeshi.dart';

/// 雙人合盤（HANDOFF §12 P5）：比較兩人年命（年柱干支）的合沖生剋，並看今年年盤上兩人年命宮的關係與門。
/// 基礎 3 分，吉因素 +1、凶因素 −1；五級沿用 [TravelLevel]。只輸出固定文句，不做開放式推演。
enum SynMode { partner, marriage }

enum SynFactor {
  stemHe(true), // 天干五合
  stemSheng(true), // 年干相生
  stemKe(false), // 年干相剋
  branchLiuHe(true), // 地支六合
  branchSanHe(true), // 地支三合
  branchChong(false), // 地支六沖
  samePalace(true), // 年命同宮
  palaceSheng(true), // 兩宮相生
  palaceKe(false), // 兩宮相剋
  doorGood(true), // 年命宮逢吉門（每人各算）
  doorBad(false), // 年命宮逢凶門
  modeGood(true); // 合夥逢生開門或值符；婚配逢休門或六合

  const SynFactor(this.good);
  final bool good;
}

class SynastryReading {
  const SynastryReading({required this.chart, required this.a, required this.b, this.palaceA, this.palaceB, required this.factors});

  final QimenChart chart;
  final BirthInfo a, b;
  final int? palaceA, palaceB;
  final List<SynFactor> factors;

  int get score => 3 + factors.fold(0, (s, f) => s + (f.good ? 1 : -1));

  TravelLevel get level => score >= 5
      ? TravelLevel.great
      : score >= 4
          ? TravelLevel.good
          : score >= 3
              ? TravelLevel.neutral
              : score >= 2
                  ? TravelLevel.minor
                  : TravelLevel.blocked;
}

class SynastryEngine {
  const SynastryEngine({this.engine = const ShiJiaEngine()});

  final ShiJiaEngine engine;

  static const _sanHe = [
    {8, 0, 4}, // 申子辰
    {11, 3, 7}, // 亥卯未
    {2, 6, 10}, // 寅午戌
    {5, 9, 1}, // 巳酉丑
  ];

  /// [at]：看哪一年的年盤（預設今年）。
  SynastryReading read(BirthInfo a, BirthInfo b, SynMode mode, DateTime at,
      {TimeSettings settings = const TimeSettings(), JuMethod method = JuMethod.chaiBu}) {
    final f = <SynFactor>[];
    final sa = a.year.stem, sb = b.year.stem;
    final ea = stemElement(sa), eb = stemElement(sb);
    if ((sa - sb).abs() == 5) {
      f.add(SynFactor.stemHe);
    } else if (ea.generates(eb) || eb.generates(ea)) {
      f.add(SynFactor.stemSheng);
    } else if (ea.overcomes(eb) || eb.overcomes(ea)) {
      f.add(SynFactor.stemKe);
    }
    final ba = a.year.branch, bb = b.year.branch;
    if ((ba + bb) % 12 == 1) {
      f.add(SynFactor.branchLiuHe); // 子丑、寅亥、卯戌、辰酉、巳申、午未：兩支相加 ≡ 1 (mod 12)
    } else if (ba != bb && _sanHe.any((g) => g.contains(ba) && g.contains(bb))) {
      f.add(SynFactor.branchSanHe);
    } else if ((ba - bb).abs() == 6) {
      f.add(SynFactor.branchChong);
    }
    final chart = engine.compute(at, settings: settings, method: method, unit: PanUnit.year);
    final pa = stemPalace(chart, a.yearStem), pb = stemPalace(chart, b.yearStem);
    if (pa != null && pb != null) {
      if (pa == pb) {
        f.add(SynFactor.samePalace);
      } else {
        final xa = palaceElement[pa]!, xb = palaceElement[pb]!;
        if (xa.generates(xb) || xb.generates(xa)) {
          f.add(SynFactor.palaceSheng);
        } else if (xa.overcomes(xb) || xb.overcomes(xa)) {
          f.add(SynFactor.palaceKe);
        }
      }
      var modeHit = false;
      for (final p in {pa, pb}) {
        final c = chart[p];
        if (c.door?.luck == Luck.good) f.add(SynFactor.doorGood);
        if (c.door?.luck == Luck.bad) f.add(SynFactor.doorBad);
        modeHit |= switch (mode) {
          SynMode.partner => c.door == Door.sheng || c.door == Door.kai || c.god == God.zhiFu,
          SynMode.marriage => c.door == Door.xiu || c.god == God.liuHe,
        };
      }
      if (modeHit) f.add(SynFactor.modeGood);
    }
    return SynastryReading(chart: chart, a: a, b: b, palaceA: pa, palaceB: pb, factors: f);
  }
}
