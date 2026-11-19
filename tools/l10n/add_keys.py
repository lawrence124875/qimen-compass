#!/usr/bin/env python3
"""一次新增多個 ARB 鍵到 10 語（簡中之後用 `l10n.py hans` 產生）。

  python3 tools/l10n/add_keys.py keys.json
keys.json：{"鍵": {"zh-Hant": "…", "en": "…", "ja": "…", "ko": "…", "vi": "…", "id": "…",
                  "es": "…", "pt-BR": "…", "th": "…", "ar": "…", "@": {placeholders…}（選填）}}
已存在的鍵會被覆蓋。之後跑：l10n.py hans → gen → check --strict。
"""
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import l10n  # noqa: E402

new = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
for lang, fname in l10n.ARB.items():
    if lang == 'zh-Hans':
        continue
    p = l10n.L10N / fname
    arb = json.loads(p.read_text(encoding='utf-8'))
    for k, v in new.items():
        if lang not in v:
            sys.exit(f'{k} 缺 {lang}')
        arb[k] = v[lang]
        if lang == 'zh-Hant' and '@' in v:
            arb['@' + k] = v['@']
    if lang != 'zh-Hant':  # 依範本順序重排（同 l10n.py fill）
        tpl = l10n.read_arb(l10n.TEMPLATE)
        out = {'@@locale': arb.get('@@locale', fname[4:-4])}
        out.update({k: arb[k] for k in l10n.msg_keys(tpl) if k in arb})
        arb = out
    l10n.write_arb(p, arb)
print(f'已加入 {len(new)} 鍵 × 10 語')
