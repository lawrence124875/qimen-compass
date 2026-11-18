"""產生奇門羅盤圖示 SVG（九宮羅盤）。所有元素以 (54,54) 為中心對稱，確保完全置中。"""
import math
GOLD, BRIGHT, PALE, BROWN = "#C9A45C", "#D8B56A", "#E8D9B0", "#7E6A52"
H = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">'
BG = ('<defs><radialGradient id="g" cx="50%" cy="50%" r="70%"><stop offset="0" stop-color="#2E2B38"/>'
      '<stop offset="1" stop-color="#1C1B22"/></radialGradient></defs><rect width="108" height="108" fill="url(#g)"/>')

def art(mono=False):
    c = (lambda x: "#FFFFFF") if mono else (lambda x: x)
    s = [f'<circle cx="54" cy="54" r="27.5" fill="none" stroke="{c(GOLD)}" stroke-width="1.4"/>']
    for i in range(24):
        major = i % 3 == 0
        r0, r1 = 27.5, 27.5 - (3 if major else 1.7)
        a = math.radians(i * 15)
        x0, y0 = 54 + r0 * math.sin(a), 54 - r0 * math.cos(a)
        x1, y1 = 54 + r1 * math.sin(a), 54 - r1 * math.cos(a)
        s.append(f'<line x1="{x0:.2f}" y1="{y0:.2f}" x2="{x1:.2f}" y2="{y1:.2f}" stroke="{c(GOLD)}" '
                 f'stroke-width="{1.1 if major else .7}"/>')
    for r in range(3):
        for k in range(3):
            mid = r == k == 1
            x, y = 54 - 12.5 + k * 8.75, 54 - 12.5 + r * 8.75  # 三格寬 25，中心 54
            fill = c(GOLD) if mid else "none"
            s.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="7.25" height="7.25" rx="1" fill="{fill}" '
                     f'stroke="{c(GOLD) if mid else c(BROWN)}" stroke-width=".9"/>')
    d = 11.2  # 指針：兩端對中心點對稱
    s.append(f'<line x1="{54+d+.3:.2f}" y1="{54-d-.3:.2f}" x2="{54+d+6+.3:.2f}" y2="{54-d-6-.3:.2f}" stroke="{c(PALE)}" stroke-width="1.4" stroke-linecap="round"/>')
    s.append(f'<line x1="{54-d-.3:.2f}" y1="{54+d+.3:.2f}" x2="{54-d-6-.3:.2f}" y2="{54+d+6+.3:.2f}" stroke="{c(BROWN)}" stroke-width="1.4" stroke-linecap="round"/>')
    return "".join(s)

files = {
    "icon_foreground.svg": H.format(vb="0 0 108 108") + art() + "</svg>",
    "icon_monochrome.svg": H.format(vb="0 0 108 108") + art(True) + "</svg>",
    "icon_background.svg": H.format(vb="0 0 108 108") + BG + "</svg>",
    "icon_full.svg": H.format(vb="0 0 108 108") + BG + art() + "</svg>",
    "icon_legacy.svg": H.format(vb="16 16 76 76") + BG + art() + "</svg>",  # 舊版圖示／商店 512：裁掉外圈
}
for n, t in files.items():
    open(n, "w").write(t + "\n")
