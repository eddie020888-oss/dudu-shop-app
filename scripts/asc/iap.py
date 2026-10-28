#!/usr/bin/env python3
"""用 Codemagic 注入的 App Store Connect API 密钥：给 App 打开 Game Center，建内购商品（宝石 4 档 + 新手礼包，中英文、价格、地区、审核截图）。
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


import hashlib
PRODUCTS = [
    # productId, 名称（内部）, 美元价, 中文名, 中文说明, 英文名, 英文说明
    ("com.eddiejiang.islandme.starter", "Starter Pack", "1.99", "新手礼包", "200 宝石 + 背包 5 格 + 体力 100，只能买一次", "Starter Pack", "200 gems + 5 bag slots + 100 energy. One time only."),
    ("com.eddiejiang.islandme.gems80", "Gems 80", "1.99", "一小袋宝石", "80 颗宝石", "Pouch of Gems", "80 gems"),
    ("com.eddiejiang.islandme.gems220", "Gems 220", "4.99", "一袋宝石", "220 颗宝石（多送 10%）", "Bag of Gems", "220 gems (+10% bonus)"),
    ("com.eddiejiang.islandme.gems480", "Gems 480", "9.99", "一盒宝石", "480 颗宝石（多送 20%）", "Box of Gems", "480 gems (+20% bonus)"),
    ("com.eddiejiang.islandme.gems1000", "Gems 1000", "19.99", "一箱宝石", "1000 颗宝石（多送 25%）", "Chest of Gems", "1000 gems (+25% bonus)"),
]
SHOT = ROOT / "store/iap_review.png"
NOTE = "Gems are a consumable currency used in the Dudu Shop (tap the gem counter at the top of the Shop tab). The Starter Pack can only be bought once (enforced in-app)."

existing = {x["attributes"]["productId"]: x for x in get(f"/v1/apps/{APP}/inAppPurchasesV2?limit=200")}
terrs = [t["id"] for t in get("/v1/territories?limit=200")]
print("已有", list(existing), "地区", len(terrs))

for pid, name, usd, zn, zd, en, ed in PRODUCTS:
    step(pid)
    if pid in existing:
        iid = existing[pid]["id"]; print("已存在", iid)
    else:
        j = req("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases",
                "attributes": {"name": name, "productId": pid, "inAppPurchaseType": "CONSUMABLE", "reviewNote": NOTE, "familySharable": False},
                "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        if not j: continue
        iid = j["data"]["id"]
    locs = {l["attributes"]["locale"] for l in get(f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations")}
    for loc, n, dsc in (("zh-Hans", zn, zd), ("en-US", en, ed)):
        if loc not in locs:
            req("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
                "attributes": {"locale": loc, "name": n, "description": dsc},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
    # 价格：以美国定价，别的地区苹果自动换算
    pts = get(f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]=USA&limit=200")
    pp = next((p for p in pts if p["attributes"]["customerPrice"] == usd), None)
    if pp:
        req("POST", "/v1/inAppPurchasePriceSchedules", {"data": {"type": "inAppPurchasePriceSchedules",
            "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                              "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                              "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p0}"}]}}},
            "included": [{"type": "inAppPurchasePrices", "id": "${p0}", "attributes": {"startDate": None},
                          "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp["id"]}}}}]}, ok=(201, 409))
    else:
        print("!! 找不到价格点", usd)
    req("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                          "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terrs]}}}}, ok=(201, 409))
    # 审核截图
    if SHOT.exists():
        cur = req("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot", ok=(200,), quiet=True)
        if not (cur and cur.get("data")):
            b = SHOT.read_bytes()
            j = req("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
                "attributes": {"fileName": SHOT.name, "fileSize": len(b)},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
            if j:
                sid = j["data"]["id"]
                for op in j["data"]["attributes"]["uploadOperations"]:
                    hd = {h["name"]: h["value"] for h in op["requestHeaders"]}
                    requests.request(op["method"], op["url"], headers=hd, data=b[op["offset"]:op["offset"] + op["length"]], timeout=120)
                req("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
                    "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(b).hexdigest()}}})

step("结果")
for x in get(f"/v1/apps/{APP}/inAppPurchasesV2?limit=200"):
    a = x["attributes"]; print(a["productId"], a.get("state"))
