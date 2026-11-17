#!/usr/bin/env python3
"""產生字型子集（思源黑體／宋體 TC），輸出到 assets/fonts/（不進 repo，比照謙卦）。

- 來源固定在 noto-cjk 的發佈 tag，確保每次建置字形一致。
- 收字範圍：lib/ 下所有 .dart 與 .arb、assets/content/ 下所有 .json 用到的字＋ASCII＋常用全形標點。
  其他語言用補字字型（FALLBACKS），在 app_theme.dart 的 kFontFallback 依序使用。
用法：pip install fonttools && python3 scripts/build_fonts.py
"""
import pathlib
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'fonts'
CACHE = ROOT / '.dart_tool' / 'font_src'

_SANS = 'https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/Sans/SubsetOTF/TC/'
_SERIF = 'https://raw.githubusercontent.com/notofonts/noto-cjk/Serif2.003/Serif/SubsetOTF/TC/'
SOURCES = {
    'QmSans-Regular.otf': _SANS + 'NotoSansTC-Regular.otf',
    'QmSans-Bold.otf': _SANS + 'NotoSansTC-Bold.otf',
    'QmSerif-Regular.otf': _SERIF + 'NotoSerifTC-Regular.otf',
    'QmSerif-Bold.otf': _SERIF + 'NotoSerifTC-Bold.otf',
}

# 其他語言的補字字型（只放 Regular，粗體由引擎合成）：app_theme.dart 的 kFontFallback 依序使用。
# 簡中、日、韓：noto-cjk 同一 tag 的 SubsetOTF，只收該語言 ARB／內容用到的字。
# 泰、阿拉伯：Google Fonts 固定 commit 的可變字型，固定字重 400 後整套保留（上下標記與連寫靠 OpenType）。
_GF = 'https://raw.githubusercontent.com/google/fonts/9710da1eacb3be272583c3224dcb70f9da6eadbb/ofl/'
FALLBACKS = {  # 輸出檔名: (來源, 語言檔名關鍵字；None＝不子集)
    'QmFbSC-Regular.otf': (_SANS.replace('/TC/', '/SC/') + 'NotoSansSC-Regular.otf', ('zh_Hans', 'zh-Hans')),
    'QmFbJP-Regular.otf': (_SANS.replace('/TC/', '/JP/') + 'NotoSansJP-Regular.otf', ('_ja.', '/ja.')),
    'QmFbKR-Regular.otf': (_SANS.replace('/TC/', '/KR/') + 'NotoSansKR-Regular.otf', ('_ko.', '/ko.')),
    'QmFbTH-Regular.ttf': (_GF + 'notosansthai/NotoSansThai%5Bwdth,wght%5D.ttf', None),
    'QmFbAR-Regular.ttf': (_GF + 'notosansarabic/NotoSansArabic%5Bwdth,wght%5D.ttf', None),
}

EXTRA = ''.join(chr(c) for c in range(0x20, 0x7F)) + '、。，．：；！？（）「」『』《》〈〉・…—–·○●◎◇◆□■△▲▽▼←↑→↓‹›％＋－／～０１２３４５６７８９'


def charset() -> str:
    chars = set(EXTRA)
    for p in list((ROOT / 'lib').rglob('*.dart')) + list((ROOT / 'lib').rglob('*.arb')) + list((ROOT / 'assets' / 'content').rglob('*.json')):
        chars.update(p.read_text(encoding='utf-8'))
    return ''.join(sorted(c for c in chars if c.isprintable()))


def lang_charset(keys) -> str:
    chars = set(EXTRA)
    for p in list((ROOT / 'lib').rglob('*.arb')) + list((ROOT / 'assets' / 'content').rglob('*.json')):
        if any(k in p.as_posix() for k in keys):
            chars.update(p.read_text(encoding='utf-8'))
    return ''.join(sorted(c for c in chars if c.isprintable()))


def fetch(url: str) -> pathlib.Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / url.rsplit('/', 1)[1]
    if not f.exists() or f.stat().st_size == 0:
        print(f'下載 {url}')
        with urllib.request.urlopen(url, timeout=120) as r:
            f.write_bytes(r.read())
    return f


def main() -> int:
    text = charset()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, url in SOURCES.items():
        src = fetch(url)
        opts = subset.Options()
        opts.layout_features = ['*']
        opts.name_IDs = ['*']
        opts.notdef_outline = True
        opts.hinting = False
        font = subset.load_font(str(src), opts)
        s = subset.Subsetter(opts)
        s.populate(text=text)
        s.subset(font)
        out = OUT / name
        subset.save_font(font, str(out), opts)
        print(f'{name}: {len(text)} 字，{out.stat().st_size // 1024} KB')
    for name, (url, keys) in FALLBACKS.items():
        src = fetch(url)
        out = OUT / name
        if keys is None:
            font = TTFont(str(src))
            axes = {a.axisTag for a in font['fvar'].axes}
            font = instancer.instantiateVariableFont(font, {'wght': 400, **({'wdth': 100} if 'wdth' in axes else {})})
            font.save(str(out))
        else:
            t = lang_charset(keys)
            opts = subset.Options()
            opts.layout_features = ['*']
            opts.name_IDs = ['*']
            opts.notdef_outline = True
            opts.hinting = False
            font = subset.load_font(str(src), opts)
            sub = subset.Subsetter(opts)
            sub.populate(text=t)
            sub.subset(font)
            subset.save_font(font, str(out), opts)
        print(f'{name}: {out.stat().st_size // 1024} KB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
