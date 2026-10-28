#!/usr/bin/env python3
"""用 Codemagic 注入的 App Store Connect API 密钥，把上架资料填好（不提交审核）。
读 store/metadata.json + store/screenshots/*.png。可重复跑，已经对的就跳过。
填：App 名字/副标题/隐私网址（中、英）、分类、内容版权、年龄分级、版本 1.0.0 的介绍/关键词/推广文本/支持网址/版权、
截图（6.9 英寸）、审核备注、可售地区（去掉中国大陆）、免费、选最新构建。
App 隐私问卷（数据收集）苹果没有开放 API，只能网页上点。
用法：python3 metadata.py [inspect|apply]"""
import os, sys, json, time, hashlib, pathlib
import jwt, requests

ROOT = pathlib.Path(__file__).resolve().parents[2]
M = json.load(open(ROOT / "store/metadata.json"))
APP = M["app_id"]
MODE = sys.argv[1] if len(sys.argv) > 1 else "inspect"
API = "https://api.appstoreconnect.apple.com"


def resolve(v):
    if v.startswith("@env:"): v = os.environ[v[5:]]
    if v.startswith("@file:"): v = pathlib.Path(os.path.expandvars(v[6:])).expanduser().read_text()
    elif os.path.isfile(v): v = pathlib.Path(v).read_text()
    return v


KID = os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"]; ISS = os.environ["APP_STORE_CONNECT_ISSUER_ID"]
KEY = resolve(os.environ["APP_STORE_CONNECT_PRIVATE_KEY"])
_tok = {"t": None, "at": 0}


def H():
    if time.time() - _tok["at"] > 600:
        now = int(time.time())
        _tok["t"] = jwt.encode({"iss": ISS, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}, KEY, algorithm="ES256", headers={"kid": KID, "typ": "JWT"})
        _tok["at"] = time.time()
    return {"Authorization": "Bearer " + _tok["t"], "Content-Type": "application/json"}


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


def step(title):
    print("\n=== " + title)


APPLY = MODE == "apply"

# ---------- App
step("App")
app = req("GET", f"/v1/apps/{APP}", quiet=True)["data"]
print("name:", app["attributes"].get("name"), "| primaryLocale:", app["attributes"].get("primaryLocale"), "| bundle:", app["attributes"].get("bundleId"),
      "| contentRights:", app["attributes"].get("contentRightsDeclaration"))
if APPLY and app["attributes"].get("contentRightsDeclaration") != "DOES_NOT_USE_THIRD_PARTY_CONTENT":
    req("PATCH", f"/v1/apps/{APP}", {"data": {"type": "apps", "id": APP, "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})

# ---------- App info（名字、副标题、隐私网址、分类、年龄分级）
step("App info")
infos = get(f"/v1/apps/{APP}/appInfos")
for i in infos: print("appInfo", i["id"], i["attributes"].get("state") or i["attributes"].get("appStoreState"))
info = next((i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO")), infos[0])
ils = get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")
for l in ils: print("  locale", l["attributes"]["locale"], "|", l["attributes"].get("name"), "|", l["attributes"].get("subtitle"), "|", l["attributes"].get("privacyPolicyUrl"))
if APPLY:
    for loc, v in M["locales"].items():
        attrs = {"name": v["name"], "subtitle": v["subtitle"], "privacyPolicyUrl": M["privacy_url"]}
        cur = next((l for l in ils if l["attributes"]["locale"] == loc), None)
        if cur:
            req("PATCH", f"/v1/appInfoLocalizations/{cur['id']}", {"data": {"type": "appInfoLocalizations", "id": cur["id"], "attributes": attrs}})
        else:
            req("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": dict(attrs, locale=loc),
                 "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
    c = M["categories"]
    req("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": c["primary"]}},
        "primarySubcategoryOne": {"data": {"type": "appCategories", "id": c["sub1"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": c["secondary"]}}}}})

step("Age rating")
ar = req("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration", quiet=True)
if ar:
    a = ar["data"]; print("current:", json.dumps(a["attributes"], ensure_ascii=False))
    if APPLY:
        # 苹果的年龄分级问卷字段常加新的：先全填「无 / 否」，按报错里说的类型自动改，最多试 6 次
        skip = {"kidsAgeBand", "ageRatingOverride", "koreaAgeRatingOverride", "ageRatingOverrideV2", "developerAgeRatingInfoUrl", "gracRatingClassificationNumber"}
        want = {k: "NONE" for k in a["attributes"] if k not in skip}
        for k in ("gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "userGeneratedContent", "advertising", "parentalControls", "ageAssurance", "socialMedia", "healthOrWellnessTopics"):
            if k in want: want[k] = False
        import re as _re
        for attempt in range(6):
            url = f"{API}/v1/ageRatingDeclarations/{a['id']}"
            r = requests.patch(url, headers=H(), data=json.dumps({"data": {"type": "ageRatingDeclarations", "id": a["id"], "attributes": want}}), timeout=60)
            if r.status_code < 300: print("ok age rating", json.dumps(want)); break
            errs = r.json().get("errors", [])
            changed = False
            for e in errs:
                f = (e.get("source") or {}).get("pointer", "").split("/")[-1]; d = e.get("detail", "")
                if "Expected a BOOLEAN" in d: want[f] = False; changed = True
                elif "Expected a STRING" in d or "Expected one of" in d: want[f] = "NONE"; changed = True
                elif f in want and ("not allowed" in d or "cannot" in d.lower() or "unknown" in d.lower()): want.pop(f); changed = True
            print("age rating retry", attempt, [e.get("detail", "")[:120] for e in errs][:6])
            if not changed: break

# ---------- 版本
step("Version")
vers = get(f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS")
for v in vers: print("version", v["id"], v["attributes"]["versionString"], v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState"))
ver = next((v for v in vers if (v["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"))), None)
if not ver and APPLY:
    j = req("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": M["version"]},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    ver = j and j["data"]
if ver and APPLY:
    req("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"], "attributes": {
        "versionString": M["version"], "copyright": M["copyright"], "releaseType": "AFTER_APPROVAL"}}})

if ver:
    vls = get(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
    for l in vls: print("  vloc", l["attributes"]["locale"], "| kw:", (l["attributes"].get("keywords") or "")[:40], "| support:", l["attributes"].get("supportUrl"))
    if APPLY:
        for loc, v in M["locales"].items():
            attrs = {"description": v["description"], "keywords": v["keywords"], "promotionalText": v["promo"], "supportUrl": M["support_url"]}
            cur = next((l for l in vls if l["attributes"]["locale"] == loc), None)
            if cur:
                req("PATCH", f"/v1/appStoreVersionLocalizations/{cur['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": cur["id"], "attributes": attrs}})
            else:
                j = req("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": dict(attrs, locale=loc),
                        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
                if j: vls.append(j["data"])

    # ---------- 截图（6.9 英寸 → APP_IPHONE_67）
    step("Screenshots")
    for loc, v in M["locales"].items():
        cur = next((l for l in vls if l["attributes"]["locale"] == loc), None)
        if not cur: continue
        sets = get(f"/v1/appStoreVersionLocalizations/{cur['id']}/appScreenshotSets")
        print(" ", loc, "sets:", [(s["attributes"]["screenshotDisplayType"], s["id"]) for s in sets])
        if not APPLY: continue
        st = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
        if not st:
            j = req("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": cur["id"]}}}}})
            st = j and j["data"]
        if not st: continue
        old = get(f"/v1/appScreenshotSets/{st['id']}/appScreenshots")
        if len(old) == len(v["shots"]) and os.environ.get("RESHOOT") != "1":
            print("  已有", len(old), "张，跳过（RESHOOT=1 重新传）"); continue
        for o in old: req("DELETE", f"/v1/appScreenshots/{o['id']}")
        for fn in v["shots"]:
            data = (ROOT / "store/screenshots" / fn).read_bytes()
            j = req("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": fn, "fileSize": len(data)},
                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": st["id"]}}}}})
            if not j: continue
            sid = j["data"]["id"]
            for op in j["data"]["attributes"]["uploadOperations"]:
                hdr = {h["name"]: h["value"] for h in op["requestHeaders"]}
                part = data[op["offset"]: op["offset"] + op["length"]]
                r = requests.request(op["method"], op["url"], headers=hdr, data=part, timeout=120)
                if r.status_code >= 300: print("!! upload part", r.status_code, r.text[:300])
            req("PATCH", f"/v1/appScreenshots/{sid}", {"data": {"type": "appScreenshots", "id": sid, "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
            print("   uploaded", fn)

    # ---------- 审核信息
    step("Review detail")
    rd = req("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreReviewDetail", ok=(200, 404), quiet=True)
    rdd = rd and rd.get("data")
    print("review detail:", json.dumps(rdd and rdd["attributes"], ensure_ascii=False)[:400])
    if APPLY:
        attrs = {"notes": M["review_notes"], "demoAccountRequired": False}
        # 审核联系人不放在仓库里（公开仓库），从环境变量读；没给就保留后台已有的
        for k, e in [("contactEmail", "REVIEW_CONTACT_EMAIL"), ("contactPhone", "REVIEW_CONTACT_PHONE")]:
            if os.environ.get(e): attrs[k] = os.environ[e]
        if rdd:
            req("PATCH", f"/v1/appStoreReviewDetails/{rdd['id']}", {"data": {"type": "appStoreReviewDetails", "id": rdd["id"], "attributes": attrs}})
        else:
            req("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
                 "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})

    # ---------- 构建
    step("Build")
    builds = get(f"/v1/builds?filter[app]={APP}&filter[preReleaseVersion.version]={M['version']}&sort=-uploadedDate&limit=5")
    for b in builds[:5]: print("build", b["id"], b["attributes"]["version"], b["attributes"].get("processingState"), b["attributes"].get("uploadedDate"))
    good = [b for b in builds if b["attributes"].get("processingState") == "VALID"]
    if good and APPLY:
        req("PATCH", f"/v1/appStoreVersions/{ver['id']}/relationships/build", {"data": {"type": "builds", "id": good[0]["id"]}})
        print("selected build", good[0]["attributes"]["version"])

# ---------- 价格：免费
step("Price")
ps = req("GET", f"/v1/apps/{APP}/appPriceSchedule?include=manualPrices", ok=(200, 404), quiet=True)
print("price schedule:", "exists" if ps and ps.get("data") else "none")
if APPLY and not (ps and ps.get("data") and (ps.get("included") or [])):
    pts = get(f"/v1/apps/{APP}/appPricePoints?filter[territory]=USA&limit=200")
    free = next((p for p in pts if float(p["attributes"].get("customerPrice") or 1) == 0), None)
    if free:
        req("POST", "/v1/appPriceSchedules", {"data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": APP}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${p0}"}]}}},
            "included": [{"type": "appPrices", "id": "${p0}", "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    else:
        print("!! 没找到免费价格点")

# ---------- 地区：全部，去掉中国大陆
step("Availability")
av = req("GET", f"/v1/apps/{APP}/appAvailabilityV2", ok=(200, 404), quiet=True)
print("availability:", "exists" if av and av.get("data") else "none")
if APPLY and not (av and av.get("data")):
    terrs = [t["id"] for t in get("/v1/territories?limit=200")]
    inc = []; refs = []
    for i, t in enumerate(terrs):
        lid = "${t%d}" % i
        refs.append({"type": "territoryAvailabilities", "id": lid})
        inc.append({"type": "territoryAvailabilities", "id": lid, "attributes": {"available": t not in M["exclude_territories"]},
                    "relationships": {"territory": {"data": {"type": "territories", "id": t}}}})
    req("POST", "/v2/appAvailabilities", {"data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
         "relationships": {"app": {"data": {"type": "apps", "id": APP}}, "territoryAvailabilities": {"data": refs}}}, "included": inc})

# ---------- App 隐私：不收集数据（试试 API；苹果不让就只能网页上点）
step("App privacy")
du = req("GET", f"/v1/apps/{APP}/dataUsages", ok=(200, 403, 404), quiet=True)
print("data usages:", json.dumps(du)[:300] if du else None)
if APPLY:
    have = du and du.get("data")
    if not have:
        req("POST", "/v1/appDataUsages", {"data": {"type": "appDataUsages", "relationships": {
            "app": {"data": {"type": "apps", "id": APP}},
            "dataProtection": {"data": {"type": "appDataUsageDataProtections", "id": "DATA_NOT_COLLECTED"}}}}}, ok=(200, 201))
    ps = req("GET", f"/v1/apps/{APP}/dataUsagePublishState", ok=(200, 403, 404))
    if ps and ps.get("data"):
        req("PATCH", f"/v1/appDataUsagesPublishState/{ps['data']['id']}", {"data": {"type": "appDataUsagesPublishState", "id": ps["data"]["id"], "attributes": {"published": True}}})

print("\n完成（模式：%s）。没有提交审核。App 隐私问卷要在网页上填。" % MODE)
