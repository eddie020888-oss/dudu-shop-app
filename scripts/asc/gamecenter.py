#!/usr/bin/env python3
"""用 Codemagic 注入的 App Store Connect API 密钥：给 App 打开 Game Center，建「每周交单榜」循环排行榜（中、英）。
可重复跑：已经有的就跳过。用法：python3 gamecenter.py"""
import os, sys, json, time, pathlib
import jwt, requests

ROOT = pathlib.Path(__file__).resolve().parents[2]
APP = json.load(open(ROOT / "store/metadata.json"))["app_id"]
API = "https://api.appstoreconnect.apple.com"


def resolve(v):
    if v.startswith("@env:"): v = os.environ[v[5:]]
    if v.startswith("@file:"): v = pathlib.Path(os.path.expandvars(v[6:])).expanduser().read_text()
    elif os.path.isfile(v): v = pathlib.Path(v).read_text()
    return v


KID = os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"]; ISS = os.environ["APP_STORE_CONNECT_ISSUER_ID"]
KEY = resolve(os.environ["APP_STORE_CONNECT_PRIVATE_KEY"])


def H():
    now = int(time.time())
    t = jwt.encode({"iss": ISS, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}, KEY, algorithm="ES256", headers={"kid": KID, "typ": "JWT"})
    return {"Authorization": "Bearer " + t, "Content-Type": "application/json"}


def req(method, path, body=None, ok=(200, 201, 204), quiet=False):
    url = path if path.startswith("http") else API + path
    r = requests.request(method, url, headers=H(), data=json.dumps(body) if body is not None else None, timeout=60)
    if r.status_code not in ok:
        print(f"!! {method} {path} -> {r.status_code}\n{r.text[:1500]}")
        return None
    if not quiet: print(f"ok {method} {path.split('?')[0]} {r.status_code}")
    return r.json() if r.text else {}


def get(path):
    out = []; url = path
    while url:
        j = req("GET", url, quiet=True)
        if j is None: return out
        d = j.get("data"); out += d if isinstance(d, list) else [d]
        url = (j.get("links") or {}).get("next")
    return out


def step(t): print("\n=== " + t)

BOARD = "dudu.orders.weekly"
START = "2026-10-22T07:00:00Z"     # 第一轮：太平洋时间周四 0 点开始，之后每 7 天一轮

step("Game Center 开关")
gcd = req("GET", f"/v1/apps/{APP}/gameCenterDetail", ok=(200,), quiet=True)
if gcd and gcd.get("data"):
    gid = gcd["data"]["id"]; print("已打开 Game Center", gid)
else:
    j = req("POST", "/v1/gameCenterDetails", {"data": {"type": "gameCenterDetails",
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    if not j: sys.exit("打不开 Game Center")
    gid = j["data"]["id"]; print("打开了 Game Center", gid)

step("循环排行榜 " + BOARD)
boards = get(f"/v1/gameCenterDetails/{gid}/gameCenterLeaderboards")
lb = next((b for b in boards if b["attributes"].get("vendorIdentifier") == BOARD), None)
if lb:
    print("已有", lb["id"], lb["attributes"])
else:
    j = req("POST", "/v1/gameCenterLeaderboards", {"data": {"type": "gameCenterLeaderboards",
        "attributes": {"referenceName": "Weekly orders", "vendorIdentifier": BOARD,
                       "defaultFormatter": "INTEGER", "submissionType": "BEST_SCORE", "scoreSortType": "DESC",
                       "scoreRangeStart": "0", "scoreRangeEnd": "100000",
                       "recurrenceStartDate": START, "recurrenceDuration": "PT168H", "recurrenceRule": "FREQ=DAILY;INTERVAL=7"},
        "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": gid}}}}})
    if not j: sys.exit("建排行榜失败")
    lb = j["data"]; print("建好了", lb["id"])

step("名字（中、英）")
have = {l["attributes"]["locale"] for l in get(f"/v1/gameCenterLeaderboards/{lb['id']}/localizations")}
for loc, name, suf in [("zh-Hans", "每周交单榜", " 单"), ("en-US", "Weekly Orders", " orders")]:
    if loc in have: print("已有", loc); continue
    req("POST", "/v1/gameCenterLeaderboardLocalizations", {"data": {"type": "gameCenterLeaderboardLocalizations",
        "attributes": {"locale": loc, "name": name, "formatterSuffix": suf, "formatterSuffixSingular": suf},
        "relationships": {"gameCenterLeaderboard": {"data": {"type": "gameCenterLeaderboards", "id": lb["id"]}}}}})
print("\n完成。TestFlight 里就能用（沙盒）。正式上架时还要把排行榜加到版本上、配一张图。")
