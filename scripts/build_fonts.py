#!/usr/bin/env python3
"""產生字型子集（思源黑體／宋體 TC），輸出到 assets/fonts/（不進 repo，比照謙卦）。

- 來源固定在 noto-cjk 的發佈 tag，確保每次建置字形一致。
- 收字範圍：lib/ 下所有 .dart 與 .arb 用到的字＋ASCII＋常用全形標點。
  新增語言（日韓泰阿等）換主字型時，在 SOURCES 加一組並在 app_theme.dart 設 fallback。
用法：pip install fonttools && python3 scripts/build_fonts.py
"""
import pathlib
import sys
import urllib.request

from fontTools import subset

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

EXTRA = ''.join(chr(c) for c in range(0x20, 0x7F)) + '、。，．：；！？（）「」『』《》〈〉・…—–·○●◎◇◆□■△▲▽▼←↑→↓‹›％＋－／～０１２３４５６７８９'


def charset() -> str:
    chars = set(EXTRA)
    for p in list((ROOT / 'lib').rglob('*.dart')) + list((ROOT / 'lib').rglob('*.arb')):
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
    return 0


if __name__ == '__main__':
    sys.exit(main())
