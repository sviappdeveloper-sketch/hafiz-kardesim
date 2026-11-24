#!/usr/bin/env python3
"""Google Play'e AAB yükler (Google Play Developer API, edits).

Ortam:
  ACCESS_TOKEN  androidpublisher yetkili erişim belirteci (GitHub → Workload Identity → github-deploy)
  PAKET         uygulama paket adı (ör. com.toppotada.oyun)
  AAB           yüklenecek .aab dosyası
  KANAL         production | alpha (kapalı test) | beta (açık test) | internal (dahili test)
  NOT           (isteğe bağlı) "Bu sürümde yenilikler", Türkçe
"""
import json
import os
import sys
import urllib.error
import urllib.request

TOK = os.environ["ACCESS_TOKEN"]
PKG = os.environ["PAKET"]
AAB = os.environ["AAB"]
KANAL = os.environ.get("KANAL", "alpha")
NOT = os.environ.get("NOT", "").strip()
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
UP = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"


def call(method, url, body=None, data=None, ctype="application/json"):
    req = urllib.request.Request(url, method=method,
                                 data=data if data is not None else (json.dumps(body).encode() if body is not None else None),
                                 headers={"Authorization": "Bearer " + TOK, "Content-Type": ctype})
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")
        print(f"HATA {method} {url.split('/applications/')[-1]} -> {e.code}\n{msg[:1500]}")
        sys.exit(1)


edit = call("POST", f"{API}/edits", {})["id"]
print("Düzenleme açıldı:", edit)
for t in call("GET", f"{API}/edits/{edit}/tracks").get("tracks", []):
    rel = t.get("releases") or [{}]
    print(f"  Kanal {t['track']}: " + ", ".join(f"{r.get('status')} {r.get('versionCodes')}" for r in rel))

with open(AAB, "rb") as f:
    data = f.read()
print(f"AAB yükleniyor: {AAB} ({len(data) // 1024} KB)")
b = call("POST", f"{UP}/edits/{edit}/bundles?uploadType=media", data=data, ctype="application/octet-stream")
vc = b["versionCode"]
print("Yüklendi, sürüm kodu:", vc)

rel = {"versionCodes": [str(vc)], "status": "completed"}
if NOT:
    rel["releaseNotes"] = [{"language": "tr-TR", "text": NOT[:500]}]
call("PUT", f"{API}/edits/{edit}/tracks/{KANAL}", {"track": KANAL, "releases": [rel]})
print("Kanala eklendi:", KANAL)
r = call("POST", f"{API}/edits/{edit}:commit?changesNotSentForReview=false", {})
print("YAYINLANDI / İNCELEMEYE GÖNDERİLDİ:", PKG, "sürüm kodu", vc, "kanal", KANAL)
