#!/usr/bin/env python3
"""把 1.0.0 提交给苹果审核（发财哥 2026-10-19 18:15 明确说「你直接自己提交」）。
苹果会检查：App 隐私问卷没填等缺项会在这里报错，原样打印出来。"""
import sys, json
sys.argv = [sys.argv[0], "inspect"]
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location("m", pathlib.Path(__file__).with_name("metadata.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)   # 先打印一遍现状
req, get, APP = m.req, m.get, m.APP

vers = get(f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS")
ver = next((v for v in vers if v["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")), None)
if not ver: sys.exit("没有可提交的版本：" + json.dumps([(v["attributes"]["versionString"], v["attributes"].get("appStoreState")) for v in vers]))
print("\n=== Submit", ver["attributes"]["versionString"], ver["id"])
subs = get(f"/v1/reviewSubmissions?filter[app]={APP}&filter[platform]=IOS")
sub = next((s for s in subs if s["attributes"].get("state") in ("READY_FOR_REVIEW",)), None)
for s in subs: print("existing submission", s["id"], s["attributes"].get("state"))
if not sub:
    j = req("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    if not j: sys.exit(1)
    sub = j["data"]
items = get(f"/v1/reviewSubmissions/{sub['id']}/items")
if not items:
    j = req("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
            "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                              "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
    if not j: sys.exit(1)
j = req("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
if not j: sys.exit(1)
print("已提交审核：", j["data"]["attributes"].get("state"))
