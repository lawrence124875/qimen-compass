/// 天干、地支、六十甲子與五行（純 Dart，不依賴 UI）。
library;

const List<String> stemNames = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const List<String> branchNames = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

/// 五行：0 木、1 火、2 土、3 金、4 水。
enum Element {
  wood('木'),
  fire('火'),
  earth('土'),
  metal('金'),
  water('水');

  const Element(this.zh);
  final String zh;

  /// 本五行是否剋 [other]（木剋土、火剋金、土剋水、金剋木、水剋火）。
  bool overcomes(Element other) => other.index == (index + 2) % 5;
}

/// 一組干支。[index] 為六十甲子序（0＝甲子 … 59＝癸亥）。
class GanZhi {
  const GanZhi(this.index) : assert(index >= 0 && index < 60);

  factory GanZhi.of(int stem, int branch) {
    for (var i = 0; i < 60; i++) {
      if (i % 10 == stem && i % 12 == branch) return GanZhi(i);
    }
    throw ArgumentError('干支陰陽不合：$stem/$branch');
  }

  /// 由兩個字解析，例如「甲子」。
  factory GanZhi.parse(String s) =>
      GanZhi.of(stemNames.indexOf(s[0]), branchNames.indexOf(s[1]));

  final int index;

  int get stem => index % 10;
  int get branch => index % 12;

  /// 所在旬的旬首（甲子、甲戌…）六十甲子序。
  int get xunStart => index - stem;

  /// 旬首地支：子＝0、戌＝10、申＝8、午＝6、辰＝4、寅＝2。
  int get xunBranch => xunStart % 12;

  /// 旬空的兩個地支。
  List<int> get kongWang => [(xunBranch + 10) % 12, (xunBranch + 11) % 12];

  @override
  String toString() => '${stemNames[stem]}${branchNames[branch]}';

  @override
  bool operator ==(Object other) => other is GanZhi && other.index == index;

  @override
  int get hashCode => index;
}

/// 地支所在的後天八卦宮（洛書數）。
const List<int> branchPalace = [1, 8, 8, 3, 4, 4, 9, 2, 2, 7, 6, 6];
