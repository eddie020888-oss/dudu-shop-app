#!/usr/bin/env python3
"""查 App Store 审核状态：每个版本的状态、最近的审核提交。用法：python3 status.py"""
import os, sys, json, time, pathlib
import jwt, requests
ROOT = pathlib.Path(__file__).resolve().parents[2]
APP = json.load(open(ROOT / "store/metadata.json"))["app_id"]
def resolve(v):
    if v.startswith("@env:"): v = os.environ[v[5:]]
    if v.startswith("@file:"): v = pathlib.Path(os.path.expandvars(v[6:])).expanduser().read_text()
    elif os.path.isfile(v): v = pathlib.Path(v).read_text()
    return v
KID = os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"]; ISS = os.environ["APP_STORE_CONNECT_ISSUER_ID"]
KEY = resolve(os.environ["APP_STORE_CONNECT_PRIVATE_KEY"])
now = int(time.time())
TOK = jwt.encode({"iss": ISS, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}, KEY, algorithm="ES256", headers={"kid": KID, "typ": "JWT"})
H = {"Authorization": "Bearer " + TOK}
def get(p):
    r = requests.get("https://api.appstoreconnect.apple.com" + p, headers=H, timeout=60)
    if r.status_code != 200: print("!!", p, r.status_code, r.text[:500]); return []
    return r.json().get("data", [])
print("=== 版本")
for v in get(f"/v1/apps/{APP}/appStoreVersions?limit=10"):
    a = v["attributes"]; print(a.get("versionString"), a.get("appStoreState"), a.get("appVersionState"), a.get("createdDate"))
print("=== 审核提交")
for s in get(f"/v1/reviewSubmissions?filter[app]={APP}&limit=10"):
    a = s["attributes"]; print(a.get("state"), a.get("submittedDate"), a.get("platform"))
