"""用開源 kinqimen（kentang2017，PyPI）產生參考盤原始輸出，供 golden 測試比對。

只在 GitHub Actions 執行（golden_ref.yml），輸出 JSON 推到 golden-ref 分支（不進 main）。
時間一律為北京時間（UTC+8）。
"""
import json
import os
import sys

import kinqimen as _pkg

sys.path.insert(0, os.path.dirname(_pkg.__file__))  # kinqimen 內部用 `import config`
from kinqimen import kinqimen as kq  # noqa: E402

TIMES = sys.argv[2].split()
out = []
for t in TIMES:
    y, mo, d, h, mi = map(int, t.split("-"))
    q = kq.Qimen(y, mo, d, h, mi)
    item = {"time": t}
    for opt in (1, 2):
        try:
            item[str(opt)] = q.pan(opt)
        except Exception as e:  # 記錄錯誤，不中斷
            item[str(opt)] = {"error": repr(e)}
    out.append(item)

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1, default=str)
print(f"{len(out)} 組")
