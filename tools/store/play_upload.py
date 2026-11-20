#!/usr/bin/env python3
"""上傳 AAB 到 Play 測試軌（.github/workflows/play_upload.yml 呼叫）。

  SA=<服務帳戶 JSON> TRACKS=internal,alpha STATUS=draft python3 tools/store/play_upload.py app.aab
一次 edit：上傳 bundle → 每個測試軌指派同一 versionCode（版本資訊取自 store/release_notes.txt）→ commit。
STATUS=draft 時只存草稿，之後到 Play Console「發布總覽」送審。"""
import json, os, re, sys, pathlib
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PKG = 'com.lclab.qimen'
aab = sys.argv[1]
tracks = [t.strip() for t in os.environ.get('TRACKS', 'internal,alpha').split(',') if t.strip()]
status = os.environ.get('STATUS', 'draft')
notes_src = pathlib.Path(__file__).resolve().parents[2] / 'store/release_notes.txt'
notes = [{'language': l, 'text': b} for l, b in re.findall(r'<([A-Za-z-]+)>\n(.*?)\n</\1>', notes_src.read_text(encoding='utf-8'), re.S)]
for n in notes:
    assert len(n['text']) <= 500, (n['language'], len(n['text']))

creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ['SA']), scopes=['https://www.googleapis.com/auth/androidpublisher'])
api = build('androidpublisher', 'v3', credentials=creds, cache_discovery=False)
edits = api.edits()
eid = edits.insert(packageName=PKG, body={}).execute()['id']
b = edits.bundles().upload(packageName=PKG, editId=eid,
                           media_body=MediaFileUpload(aab, mimetype='application/octet-stream', resumable=True)).execute()
code = str(b['versionCode'])
print('上傳完成 versionCode', code)
for t in tracks:
    edits.tracks().update(packageName=PKG, editId=eid, track=t, body={
        'track': t,
        'releases': [{'versionCodes': [code], 'status': status, 'releaseNotes': notes}],
    }).execute()
    print('指派到', t, status)
edits.commit(packageName=PKG, editId=eid, changesNotSentForReview=(status == 'draft')).execute()
print(f'::notice title=Play::versionCode {code} → {", ".join(tracks)}（{status}）')
