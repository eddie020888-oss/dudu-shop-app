#!/usr/bin/env python3
"""用 Codemagic 注入的 App Store Connect API 密钥，给 App ID 开通能力（目前：HealthKit）。
已开通则跳过。Codemagic 的自动签名随后会发现旧描述文件失效并自动重建。
直接复用 codemagic-cli-tools 自带的 API 客户端（和 app-store-connect 命令同一套认证）。"""
import os, sys, pathlib
from codemagic.apple.app_store_connect import AppStoreConnectApiClient, IssuerId, KeyIdentifier
from codemagic.apple.app_store_connect.provisioning.bundle_ids import BundleIds
from codemagic.apple.resources import CapabilityType

def resolve(v: str) -> str:
    """和 CLI 一样支持 @env: / @file: 前缀，以及直接给路径"""
    if v.startswith("@env:"): v = os.environ[v[5:]]
    if v.startswith("@file:"): v = pathlib.Path(os.path.expandvars(v[6:])).expanduser().read_text()
    elif os.path.isfile(v): v = pathlib.Path(v).read_text()
    return v

KID = KeyIdentifier(os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"])
ISS = IssuerId(os.environ["APP_STORE_CONNECT_ISSUER_ID"])
KEY = resolve(os.environ["APP_STORE_CONNECT_PRIVATE_KEY"])
BUNDLE = sys.argv[1]; WANT = sys.argv[2:] or ["HEALTHKIT"]

client = AppStoreConnectApiClient(KID, ISS, KEY)
bids = [b for b in client.bundle_ids.list(BundleIds.Filter(identifier=BUNDLE)) if b.attributes.identifier == BUNDLE]
if not bids: sys.exit(f"找不到 App ID {BUNDLE}")
bid = bids[0]
have = {c.attributes.capabilityType for c in client.bundle_ids.list_capabilities(bid)}
print("App ID", BUNDLE, "已有能力:", sorted(str(c) for c in have))
for cap in WANT:
    ct = CapabilityType(cap)
    if ct in have: print("已开通", cap); continue
    if cap == "ICLOUD":
        # iCloud 必须带版本设置（Xcode 6 以后那一版）；只用键值存储也一样。codemagic 的封装传不了数组，直接发请求
        payload = {"data": {"type": "bundleIdCapabilities",
                            "attributes": {"capabilityType": "ICLOUD",
                                           "settings": [{"key": "ICLOUD_VERSION", "options": [{"key": "XCODE_6", "enabled": True}]}]},
                            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid.id}}}}}
        r = client.session.post(f"{client.API_URL}/bundleIdCapabilities", json=payload)
        print("iCloud:", getattr(r, "status_code", r))
    else:
        client.bundle_id_capabilities.enable(ct, bid)
    print("已开通", cap)

# 旧描述文件不含新能力 → 删掉失效/旧的 App Store 描述文件，用发布证书重建一个同名的；
# 然后在 Codemagic 后台 Code signing identities → Fetch profiles 拉进来（一次性）。
from codemagic.apple.app_store_connect.provisioning.signing_certificates import SigningCertificates
from codemagic.apple.resources import ProfileType, ProfileState, CertificateType
profiles = [p for p in client.bundle_ids.list_profiles(bid) if p.attributes.profileType == ProfileType.IOS_APP_STORE]
good = [p for p in profiles if p.attributes.profileState == ProfileState.ACTIVE]
NAME = os.environ.get("PROFILE_NAME", "islandme_app_ag")   # Codemagic 里引用的名字
if os.environ.get("RESET_PROFILES") == "1":
    for p in profiles: print("删除描述文件:", p.attributes.name, p.attributes.profileState); client.profiles.delete(p); good = []
# 开了新能力以后旧描述文件会失效：失效的删掉（同名的也删，名字不能重复），再用同一个名字重建
for p in ([] if os.environ.get("RESET_PROFILES") == "1" else profiles):
    if p.attributes.profileState != ProfileState.ACTIVE or (not good and p.attributes.name == NAME):
        print("删除失效描述文件:", p.attributes.name, p.attributes.profileState); client.profiles.delete(p)
if not good:
    certs = [c for c in client.signing_certificates.list(SigningCertificates.Filter(certificate_type=CertificateType.DISTRIBUTION))]
    pref = [c for c in certs if "ParentLearning Distribution 20261008" in (c.attributes.displayName or c.attributes.name or "")] or certs
    if not pref: sys.exit("没有发布证书，无法创建描述文件")
    prof = client.profiles.create(NAME, ProfileType.IOS_APP_STORE, bid, [pref[0]], [])
    print("已创建描述文件:", prof.attributes.name, "证书:", pref[0].attributes.displayName or pref[0].attributes.name)
    print("→ 去 Codemagic 后台 Code signing identities → Fetch profiles 把它拉进来")
else:
    print("App Store 描述文件正常:", [p.attributes.name for p in good])
