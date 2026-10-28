"""中英双语：把 Swift 源码里所有带中文的字符串字面量包成 T("…")。

- "你好"            → T("你好")
- "第 \\(k) 章"      → T("第 {0} 章", k)        （插值变成 {0} {1} …，翻译时保留）
- 插值里如果还有中文字面量，也一起包
- 不动：注释、已经在 T( 里的、enum 原始值（case x = "…"）、带 specifier:/format: 的插值、EXCLUDE 里的
用法：python3 rewrite.py --scan  （只列出要翻的句子到 keys.json）
      python3 rewrite.py --apply （改源码）
"""
import re, sys, json, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FILES = [f for d in ("IslandMe", "Shared", "IslandMeWidget") for f in glob.glob(os.path.join(ROOT, d, "*.swift"))]
SKIP_FILES = {"L10n.swift"}
CJK = re.compile(r"[　-〿一-鿿＀-￯]")
EXCLUDE = {"芋圆"}   # 改名迁移里要原样比较的


def lex(src, i0=0, stop_at_paren=False):
    """扫一段代码，返回 [(start, end)] 顶层字符串字面量的位置（不含注释里的）。
    stop_at_paren: 扫插值里的代码，遇到配对的 ) 停下，返回结束位置。"""
    lits = []; i = i0; n = len(src); depth = 0
    while i < n:
        c = src[i]
        if c == "/" and src.startswith("//", i):
            j = src.find("\n", i); i = n if j < 0 else j; continue
        if c == "/" and src.startswith("/*", i):
            d = 1; i += 2
            while i < n and d:
                if src.startswith("/*", i): d += 1; i += 2
                elif src.startswith("*/", i): d -= 1; i += 2
                else: i += 1
            continue
        if c == '"':
            j = scan_string(src, i)
            lits.append((i, j)); i = j; continue
        if stop_at_paren:
            if c == "(": depth += 1
            elif c == ")":
                if depth == 0: return lits, i
                depth -= 1
        i += 1
    return lits, i


def scan_string(src, i):
    """src[i] == '"'，返回字符串结束后的位置"""
    i += 1
    while True:
        c = src[i]
        if c == "\\":
            if src[i + 1] == "(":
                _, j = lex(src, i + 2, stop_at_paren=True); i = j + 1; continue
            i += 2; continue
        if c == '"': return i + 1
        if c == "\n": raise ValueError("newline in string at %d" % i)
        i += 1


def split_literal(src, s, e):
    """把字面量拆成 文字段 和 插值表达式（原文）"""
    parts = []; i = s + 1; buf = ""
    while i < e - 1:
        c = src[i]
        if c == "\\" and src[i + 1] == "(":
            _, j = lex(src, i + 2, stop_at_paren=True)
            parts.append(("t", buf)); buf = ""
            parts.append(("x", (i + 2, j)))
            i = j + 1; continue
        if c == "\\": buf += src[i:i + 2]; i += 2; continue
        buf += c; i += 1
    parts.append(("t", buf))
    return parts


def has_cjk_text(parts):
    return any(k == "t" and CJK.search(v) for k, v in parts)


keys = {}


def transform(src, s, e, depth=0):
    """返回替换文本（或 None 表示不动）"""
    parts = split_literal(src, s, e)
    lit = src[s:e]
    exprs = [v for k, v in parts if k == "x"]
    # 先递归处理插值里的字面量
    new_exprs = []
    for (a, b) in exprs:
        code = src[a:b]
        new_exprs.append(rewrite_code(code, depth + 1))
    if not has_cjk_text(parts):
        if new_exprs and any(ne != src[a:b] for ne, (a, b) in zip(new_exprs, exprs)):
            # 只改插值内部
            out = ""; k = 0
            for kind, v in parts:
                if kind == "t": out += v
                else: out += "\\(" + new_exprs[k] + ")"; k += 1
            return '"' + out + '"'
        return None
    if any("specifier:" in src[a:b] or "format:" in src[a:b] for a, b in exprs):
        print("SKIP specifier:", lit[:60], file=sys.stderr); return None
    tmpl = ""; k = 0
    for kind, v in parts:
        if kind == "t": tmpl += v
        else: tmpl += "{%d}" % k; k += 1
    if tmpl in EXCLUDE: return None
    # en.json 的键要和运行时字符串一样：把 \n \" \\ 这些转义还原成真字符
    k = re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), tmpl)
    keys[k] = keys.get(k, 0) + 1
    args = "".join(", " + ne for ne in new_exprs)
    return 'T("' + tmpl + '"' + args + ")"


def rewrite_code(code, depth=0):
    lits, _ = lex(code)
    out = []; last = 0
    for s, e in lits:
        before = code[max(0, s - 60):s]
        if re.search(r"\bT\(\s*$", before) or re.search(r"case\s+\w+\s*=\s*$", before) \
           or re.search(r"(LocalizedStringResource\s*=|IntentDescription\(|@Parameter\(title:)\s*$", before):   # App Intents 要字面量
            continue
        rep = transform(code, s, e, depth)
        if rep is None: continue
        out.append(code[last:s]); out.append(rep); last = e
    out.append(code[last:])
    return "".join(out)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "--scan"
    changed = 0
    for f in sorted(FILES):
        if os.path.basename(f) in SKIP_FILES: continue
        src = open(f, encoding="utf-8").read()
        new = rewrite_code(src)
        if new != src:
            changed += 1
            if mode == "--apply": open(f, "w", encoding="utf-8").write(new)
    json.dump(sorted(keys), open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "keys.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print("files", changed, "unique", len(keys), "uses", sum(keys.values()))
