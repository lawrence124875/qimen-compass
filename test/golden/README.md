# 時家轉盤 golden tests

目前 35 組（`cases/*_kinqimen.json`，拆補法）：由開源 kinqimen 0.0.6.6 產生（`tools/golden/kinqimen_ref.py`，手動執行 `golden_ref.yml`，結果推到 `golden-ref` 分支），逐宮與本引擎交叉比對一致才收錄。排除：
- 交節前後的年柱、月柱：kinqimen 以整日換月，本引擎以交節時刻（`lunar` 的 Exact 干支）為準，這 7 組不比對 `pillars`。
- 時干入中五宮（星伏吟）的 2 組：kinqimen 天盤天干算錯（伏吟時天盤應同地盤），改由單元測試以規則把關。
- 置閏法：kinqimen 的置閏與公開盤例不符，不採用；置閏改由單元測試對照公開盤例（`test/engine/engine_test.dart`）。

每個參考盤一個 JSON 檔，放在 `cases/`（檔名例如 `001_dongzhi_boundary.json`）。CI 的 `flutter test` 會自動比對。
目前沒有檔案時，測試顯示為 skip。目標至少 30 組，涵蓋：陰陽遁交界（冬至、夏至前後）、節氣交界、子時（23 點、0 點）、置閏法。

## 格式

```json
{
  "name": "2024 冬至交節後 10 分鐘",
  "source": "參考軟體名稱與版本",
  "input": {
    "datetime": "2024-12-21T17:30",
    "utcOffset": "+08:00",
    "method": "chaiBu",
    "trueSolarTime": false,
    "longitude": null,
    "ziHour": "nextDay"
  },
  "expected": {
    "dun": "yang",
    "ju": 1,
    "yuan": "上元",
    "term": "冬至",
    "pillars": "甲辰 丙子 ○○ ○○",
    "zhiFu": "天蓬",
    "zhiShi": "休門",
    "palaces": {
      "1": { "heaven": "戊", "earth": "戊", "star": "天蓬", "door": "休門", "god": "值符" },
      "2": { "heaven": "己丙", "earth": "己丙", "star": "天芮/天禽", "door": "死門", "god": "九天" }
    }
  }
}
```

- `input.method`：`chaiBu`（拆補，預設）或 `zhiRun`（置閏）。`ziHour`：`nextDay`（23 點換日，預設）或 `lateZi`（分早晚子時）。
- `expected` 的每個欄位都可省略，只比對有寫的。宮位鍵為洛書數 1–9（坎1 坤2 震3 巽4 中5 乾6 兌7 艮8 離9）。
- 天干寫成連續字串：坤二宮地盤含寄宮的中五宮天干（例如「己丙」）；天芮所落宮的天盤含天禽帶來的天干，九星寫「天芮/天禽」。
- 八神用：值符、螣蛇、太陰、六合、白虎、玄武、九地、九天。
- 參考軟體若用「勾陳／朱雀」，請改寫成「白虎／玄武」。
