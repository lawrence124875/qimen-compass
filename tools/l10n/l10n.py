#!/usr/bin/env python3
"""11 語翻譯工具（比照謙卦 iching-content tools/glossary.py、check_translation.py；說明見 tools/l10n/README.md）。

  python3 tools/l10n/l10n.py check [--strict]  # 術語表完整、ARB 參數一致、術語鍵＝術語表、產生檔是最新；--strict 連缺鍵也算錯
  python3 tools/l10n/l10n.py status            # 各語言缺幾個鍵
  python3 tools/l10n/l10n.py missing ja        # 印出 ja 缺的鍵（JSON：{鍵: [繁中, 英文]}），翻好後用 fill 寫回
  python3 tools/l10n/l10n.py fill ja x.json    # 把 {鍵: 譯文} 合併進 app_ja.arb（依範本順序重排）
  python3 tools/l10n/l10n.py apply             # 術語表 ui 區的值寫入各 ARB（levelGreat、dirN…）
  python3 tools/l10n/l10n.py hans              # app_zh.arb → app_zh_Hans.arb（OpenCC tw2sp＋術語鎖定，乾不可變干）
  python3 tools/l10n/l10n.py gen               # 術語表 → lib/l10n/terms_data.dart（進 repo）

新增 ARB 鍵後：apply → hans → 各語 missing／fill → gen → check。
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GLOSSARY = ROOT / 'tools/l10n/glossary.json'
L10N = ROOT / 'lib/l10n'
TEMPLATE = L10N / 'app_zh.arb'
DART = L10N / 'terms_data.dart'
GLOSS_LANGS = ['en', 'ja', 'ko', 'vi', 'id', 'es', 'pt-BR', 'th', 'ar']
# 語言代碼 → ARB 檔（Flutter 以 locale 命名）
ARB = {'zh-Hant': 'app_zh.arb', 'zh-Hans': 'app_zh_Hans.arb', 'en': 'app_en.arb', 'ja': 'app_ja.arb', 'ko': 'app_ko.arb',
       'vi': 'app_vi.arb', 'id': 'app_id.arb', 'es': 'app_es.arb', 'pt-BR': 'app_pt.arb', 'th': 'app_th.arb', 'ar': 'app_ar.arb'}
# OpenCC 之後再換成大陸慣用說法
HANS_FIX = {'推播': '推送', '・': '·', '目前时盘': '当前时盘', '目前朝向': '当前朝向'}
SECTIONS = ['doors', 'stars', 'gods', 'palaces', 'marks', 'dun', 'yuan', 'solarTerms']
# 繁中殘留檢查（簡中 ARB 不應出現）
TRAD = set('門開陽陰時盤設與機啟點擊這們個來還麼裡後當動說書會對東車馬長兩錢氣')


def load_glossary():
    return json.loads(GLOSSARY.read_text(encoding='utf-8'))


def read_arb(p):
    return json.loads(p.read_text(encoding='utf-8'))


def write_arb(p, d):
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def msg_keys(d):
    return [k for k in d if not k.startswith('@')]


def params(v):
    # select／plural 分支（前面接英數字的 {）不算參數
    return set(re.findall(r'(?<![A-Za-z0-9_=])\{(\w+)\s*[,}]', v))


def check_glossary(g, errs):
    langs = [l['code'] for l in g['languages']]
    if langs != list(ARB):
        errs.append(f'語言清單應為 {list(ARB)}')
    for sec in SECTIONS + ['ui']:
        seen = set()
        for e in g[sec]:
            k = e.get('key', e.get('arb'))
            if k in seen:
                errs.append(f'{sec} 重複 {k}')
            seen.add(k)
            for lc in langs:
                if not e.get(lc):
                    errs.append(f'{sec}.{k} 缺 {lc}')
            if sec != 'ui' and not e.get('pinyin'):
                errs.append(f'{sec}.{k} 缺拼音')
            if '乾' in e['zh-Hant'] and '乾' not in e['zh-Hans']:
                errs.append(f'{sec}.{k} 簡中「乾」被轉掉了')
    if [e['zh-Hant'] for e in g['solarTerms']][:4] != ['冬至', '小寒', '大寒', '立春']:
        errs.append('節氣順序須與 calendar_service.dart solarTermNames 相同（冬至起）')


def check_arbs(g, errs, warns, strict):
    tpl = read_arb(TEMPLATE)
    keys = msg_keys(tpl)
    ui = {e['arb']: e for e in g['ui']}
    for lc, fn in ARB.items():
        p = L10N / fn
        if not p.exists():
            warns.append(f'{fn} 尚未建立')
            continue
        d = read_arb(p)
        extra = [k for k in msg_keys(d) if k not in tpl]
        if extra:
            errs.append(f'{fn} 多出範本沒有的鍵：{extra}')
        miss = [k for k in keys if k not in d]
        if miss:
            (errs if strict else warns).append(f'{fn} 缺 {len(miss)} 個鍵：{miss[:8]}{"…" if len(miss) > 8 else ""}')
        for k in keys:
            if k in d:
                a, b = params(d[k]), params(tpl[k])
                if a != b:
                    errs.append(f'{fn} {k} 參數 {sorted(a)} ≠ 範本 {sorted(b)}')
                if not str(d[k]).strip():
                    errs.append(f'{fn} {k} 是空字串')
                if k in ui and d[k] != ui[k][lc]:
                    errs.append(f'{fn} {k}＝「{d[k]}」≠ 術語表「{ui[k][lc]}」（跑 apply）')
        if lc == 'zh-Hans':
            for k in keys:
                bad = TRAD & set(d.get(k, ''))
                if bad:
                    errs.append(f'{fn} {k} 殘留繁體字 {"".join(sorted(bad))}')
            if re.search(r'干[宫卦]', json.dumps(d, ensure_ascii=False)):
                errs.append(f'{fn} 出現「干宫／干卦」（乾不可轉為干）')


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def gen_dart(g):
    out = ['// 由 tools/l10n/l10n.py gen 從 tools/l10n/glossary.json 產生，請勿手改。',
           '// ignore_for_file: lines_longer_than_80_chars', '', "part of 'terms.dart';", '']
    names = {'doors': '_doorTerms', 'stars': '_starTerms', 'gods': '_godTerms', 'palaces': '_palaceTerms',
             'marks': '_markTerms', 'dun': '_dunTerms', 'yuan': '_yuanTerms'}
    def entry(e):
        gl = ', '.join(f'{dart_str(lc)}: {dart_str(e[lc])}' for lc in GLOSS_LANGS)
        return f"TermEntry({dart_str(e['zh-Hant'])}, {dart_str(e['zh-Hans'])}, {dart_str(e['pinyin'])}, {{{gl}}})"
    for sec, var in names.items():
        out.append(f'const {var} = <String, TermEntry>{{')
        for e in g[sec]:
            out.append(f"  {dart_str(e['key'])}: {entry(e)},")
        out.append('};')
        out.append('')
    out.append('/// 24 節氣，順序同 solarTermNames（冬至起）。')
    out.append('const _solarTermTerms = <TermEntry>[')
    for e in g['solarTerms']:
        out.append(f'  {entry(e)},')
    out.append('];')
    return '\n'.join(out) + '\n'


def hans(g):
    import opencc
    cc = opencc.OpenCC('tw2sp')
    lock = {}
    for sec in SECTIONS + ['ui']:
        for e in g[sec]:
            if len(e['zh-Hant']) > 1 or '乾' in e['zh-Hant']:
                lock[e['zh-Hant']] = e['zh-Hans']
    lock.update({'乾': '乾', '奇門': '奇门'})
    order = sorted(lock, key=len, reverse=True)
    tpl = read_arb(TEMPLATE)
    out = {'@@locale': 'zh_Hans'}
    for k in msg_keys(tpl):
        s = tpl[k]
        ph = {}
        def keep(m):
            ph[f'{len(ph)}'] = m.group(0)
            return f'{len(ph) - 1}'
        s = re.sub(r'\{\w+[^{}]*\}', keep, s)
        for t in order:
            if t in s:
                ph[f'{len(ph)}'] = lock[t]
                s = s.replace(t, f'{len(ph) - 1}')
        s = cc.convert(s).replace('「', '“').replace('」', '”')
        for x, y in HANS_FIX.items():
            s = s.replace(x, y)
        for a, b in ph.items():
            s = s.replace(a, b)
        out[k] = s
    write_arb(L10N / ARB['zh-Hans'], out)
    print(f'已產生 {ARB["zh-Hans"]}（{len(out) - 1} 個鍵）')


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    g = load_glossary()
    if cmd == 'check':
        errs, warns = [], []
        check_glossary(g, errs)
        check_arbs(g, errs, warns, '--strict' in sys.argv)
        if DART.read_text(encoding='utf-8') != gen_dart(g) if DART.exists() else True:
            errs.append('lib/l10n/terms_data.dart 不是最新（跑 gen）')
        for w in warns:
            print(f'::warning::{w}')
        for e in errs:
            print(f'::error::{e}')
        print(f'翻譯檢查：{len(errs)} 個錯誤、{len(warns)} 個提醒')
        sys.exit(1 if errs else 0)
    elif cmd == 'status':
        keys = msg_keys(read_arb(TEMPLATE))
        for lc, fn in ARB.items():
            p = L10N / fn
            n = len([k for k in keys if k not in read_arb(p)]) if p.exists() else len(keys)
            print(f'{lc:8} 缺 {n:3} / {len(keys)}')
    elif cmd == 'missing':
        lc = sys.argv[2]
        tpl, en = read_arb(TEMPLATE), read_arb(L10N / ARB['en'])
        p = L10N / ARB[lc]
        d = read_arb(p) if p.exists() else {}
        miss = {k: [tpl[k], en.get(k, '')] for k in msg_keys(tpl) if k not in d}
        print(json.dumps(miss, ensure_ascii=False, indent=1))
    elif cmd == 'fill':
        lc, src = sys.argv[2], Path(sys.argv[3])
        tpl = read_arb(TEMPLATE)
        p = L10N / ARB[lc]
        d = read_arb(p) if p.exists() else {}
        d.update(json.loads(src.read_text(encoding='utf-8')))
        loc = ARB[lc][4:-4]
        out = {'@@locale': loc}
        out.update({k: d[k] for k in msg_keys(tpl) if k in d})
        write_arb(p, out)
        print(f'{ARB[lc]}：{len(out) - 1} 個鍵')
    elif cmd == 'apply':
        for lc, fn in ARB.items():
            p = L10N / fn
            if not p.exists():
                continue
            d = read_arb(p)
            if lc == 'zh-Hant' and all(d.get(e['arb']) == e[lc] for e in g['ui']):
                continue  # 範本沒變就不重寫（保留原排版）
            for e in g['ui']:
                d[e['arb']] = e[lc]
            if lc != 'zh-Hant':  # 依範本順序重排（範本本身保留 @ 說明）
                tpl = read_arb(TEMPLATE)
                d = {'@@locale': d.get('@@locale', fn[4:-4]), **{k: d[k] for k in msg_keys(tpl) if k in d}}
            write_arb(p, d)
        print('已寫入術語表 ui 區')
    elif cmd == 'hans':
        hans(g)
    elif cmd == 'gen':
        DART.write_text(gen_dart(g), encoding='utf-8')
        print(f'已產生 {DART.relative_to(ROOT)}')
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == '__main__':
    main()
