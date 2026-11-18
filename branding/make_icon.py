"""產生奇門羅盤圖示 SVG（九宮羅盤）。所有元素以 (54,54) 為中心對稱，確保完全置中。"""
GOLD, BRIGHT, PALE, BROWN = "#C9A45C", "#D8B56A", "#E8D9B0", "#7E6A52"
H = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">'
BG = ('<defs><radialGradient id="g" cx="50%" cy="50%" r="70%"><stop offset="0" stop-color="#2E2B38"/>'
      '<stop offset="1" stop-color="#1C1B22"/></radialGradient></defs><rect width="108" height="108" fill="url(#g)"/>')

def art(mono=False):
    """原稿座標（環半徑 32、九宮 40–68），整體以中心縮 0.86 放進安全區。"""
    c = (lambda x: "#FFFFFF") if mono else (lambda x: x)
    s = [f'<circle cx="54" cy="54" r="32" fill="none" stroke="{c(GOLD)}" stroke-width="1.6"/>']
    for i in range(24):
        major = i % 3 == 0
        s.append(f'<line x1="54" y1="22" x2="54" y2="{25.5 if major else 24}" stroke="{c(GOLD)}" '
                 f'stroke-width="{1.2 if major else .8}" transform="rotate({i*15} 54 54)"/>')
    for r in range(3):
        for k in range(3):
            mid = r == k == 1
            s.append(f'<rect x="{40+k*10}" y="{40+r*10}" width="8" height="8" rx="1.2" '
                     f'fill="{c(GOLD) if mid else "none"}" stroke="{c(GOLD) if mid else c(BROWN)}" stroke-width="1"/>')
    # 指針：從環內延伸到九宮角格，兩端對中心點對稱
    s.append(f'<path d="M74 34 L60 48" stroke="{c(PALE)}" stroke-width="1.6" stroke-linecap="round"/>')
    s.append(f'<path d="M34 74 L48 60" stroke="{c(BROWN)}" stroke-width="1.6" stroke-linecap="round"/>')
    return '<g transform="translate(54 54) scale(.86) translate(-54 -54)">' + "".join(s) + "</g>"

files = {
    "icon_foreground.svg": H.format(vb="0 0 108 108") + art() + "</svg>",
    "icon_monochrome.svg": H.format(vb="0 0 108 108") + art(True) + "</svg>",
    "icon_background.svg": H.format(vb="0 0 108 108") + BG + "</svg>",
    "icon_full.svg": H.format(vb="0 0 108 108") + BG + art() + "</svg>",
    "icon_legacy.svg": H.format(vb="16 16 76 76") + BG + art() + "</svg>",  # 舊版圖示／商店 512：裁掉外圈
}
for n, t in files.items():
    open(n, "w").write(t + "\n")
