"""嘟嘟小店 · 合成厨房逐步模拟（2026-10-19，照 MergeKitchen.swift 当前逻辑）

一个「普通玩家」机器人：每天开 3 次店、每次 12 分钟、每 2 秒一个动作。
策略（贪心，近似真人）：能交单就交 → 能做菜就放进厨具 → 合成订单需要的链（只合到订单需要的级别）
→ 点订单需要的产出器 → 台子太满就卖最没用的 → 星星够就装修。
输出：每天的等级、交单数、单子里各链占比、平均几样/几级、急单赶上率、空等比例、装修到第几章、门单亮了几个。
"""
import random, re, collections, sys

R = random.Random(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
COLS, ROWS = 8, 9
CELLS = COLS * ROWS
CHAINS = [("rice", 1), ("veg", 1), ("tea", 2), ("sweet", 3), ("fruit", 5), ("snack", 7), ("milk", 10), ("egg", 13), ("coffee", 16), ("honey", 19)]
APPL = {"pot": 4, "oven": 6, "juicer": 8, "icecream": 11, "steamer": 14, "coffeemaker": 16}
src = open(__file__.replace("sim/kitchen_sim.py", "IslandMe/MergeKitchen.swift")).read()
RECIPES = [(m[0], m[1], re.findall(r'"(\w+)"', m[2]), float(m[3]), int(m[4]), m[5]) for m in
           re.findall(r'Recipe\(id: "(\w+)",\s*name: T\("[^"]+"\),\s*at: "(\w+)",\s*needs: \[([^\]]+)\],\s*minutes: ([\d.]+),\s*unlock: (\d+),\s*food: "\w+"(, book: "\w+")?', src)]
RECIPES = [r for r in RECIPES if not r[5]]          # 不算要买菜谱书的
story = open(__file__.replace("sim/kitchen_sim.py", "IslandMe/MergeKitchenStory.swift")).read()
TASKS = [int(x) for x in re.findall(r'Tk\("\w+", T\("[^"]+"\), (\d+),', story)]
CH_LEN = 6

def chain_of(i):
    for k, _ in CHAINS:
        if i.startswith(k) and i[len(k):].isdigit(): return k
    return None
def tier(i): return int(i[len(chain_of(i)):]) if chain_of(i) else 0
def value(i):
    if chain_of(i): return 1 << (tier(i) - 1)
    r = next((r for r in RECIPES if r[0] == i), None)
    return sum(value(n) for n in r[2]) * 2 if r else 1
def recipe(i): return next((r for r in RECIPES if r[0] == i), None)
def base_chains(r):
    out = set()
    for n in r[2]:
        if chain_of(n): out.add(chain_of(n))
        elif recipe(n): out |= base_chains(recipe(n))
    return out
def is_deep(r): return len(r[2]) > 2 or any(recipe(n) for n in r[2])
MODE = sys.argv[2] if len(sys.argv) > 2 else "new"     # old：原来的随机单；new：1易2中1难 + 回来先给简单的 + 深菜
if MODE == "old": RECIPES = [r for r in RECIPES if not is_deep(r)]
BAND_PLAN = [0, 1, 1, 2]
import os
REGEN = float(os.environ.get('REGEN', 90))
LVUP_FULL = os.environ.get('LVUP', 'full') == 'full'
EASY_GAP = int(sys.argv[3]) * 60 if len(sys.argv) > 3 else 15 * 60
def xp_need(L): return 30 + L * 20 + max(0, L - 8) * L * 4
# 当前上线的数值（2026-10-19 方案 F）
TOP = lambda L: min(6, 4 + L // 6)
STARS = lambda v: max(1, min(8, round(v / 3.5)))
ORDER_XP = lambda v: max(1, v // 3)
MERGE_XP_TIER = 4
FREE_REFILLS = 6          # 新手期一天免费装满几次
def order_top(L): return TOP(L)
def order_stars(v): return STARS(v)

class G:
    def __init__(s):
        s.board = [None] * CELLS; s.gen = {}  # cell -> dict(chain, charges, refill_at)
        s.L, s.xp, s.stars, s.gems = 1, 0, 0, 10
        s.done = 0; s.lit = 0; s.orders = []; s.t = 0.0; s.energy = 100; s.focus = []; s.focus_day = -1
        s.cook = {}; s.free_refills_today = 0; s.boost_until = 0  # appliance -> (dish, ready_at)
        s.stats = collections.Counter(); s.chain_ct = collections.Counter(); s.items_ct = []; s.tier_ct = []
        s.served_ids = 0; s.rush_ok = 0; s.rush_miss = 0; s.idle = 0; s.act = 0
        s.place_gen("rice", 8 * COLS + 1); s.place_gen("veg", 8 * COLS + 5)
        s.refresh_focus(0)
        s.orders.append(dict(items=["rice2"], stars=1, kind="first"))
        while len(s.normal()) < 4: s.orders.append(s.new_order())
    def unlocked(s): return [k for k, u in CHAINS if u <= s.L]
    def place_gen(s, k, near):
        c = s.empty(near)
        if c is None: c = s.sell_one(force=True)
        s.board[c] = "gen_" + k; s.gen[c] = dict(chain=k, charges=24, refill=None)
    def empty(s, near=0):
        es = [i for i in range(CELLS) if s.board[i] is None]
        return min(es, key=lambda i: abs(i // COLS - near // COLS) + abs(i % COLS - near % COLS)) if es else None
    def normal(s): return [o for o in s.orders if o["kind"] in ("normal", "first", "rush")]
    def refresh_focus(s, day):
        uk = s.unlocked()
        if s.focus_day != day or len(s.focus) < min(3, len(uk)) or any(k not in uk for k in s.focus):
            s.focus_day = day
            rs = [r for r in RECIPES if r[4] <= s.L and base_chains(r) <= set(uk)]
            pick = list(base_chains(R.choice(rs))) if rs else []
            for k in R.sample(uk, len(uk)):
                if len(pick) < 3 and k not in pick: pick.append(k)
            s.focus = pick
    def focus_dishes(s):
        ap = [a for a, u in APPL.items() if u <= s.L]
        return [r for r in RECIPES if r[4] <= s.L and r[1] in ap and base_chains(r) <= set(s.focus)]
    def band_of(s, o):
        if "band" in o: return o["band"]
        return 1
    def next_band(s, except_o=None):
        need = list(BAND_PLAN)
        for o in s.normal():
            if o is except_o: continue
            b = s.band_of(o)
            if b in need: need.remove(b)
        b = need[0] if need else 1
        return 1 if b == 0 and s.t < getattr(s, "easy_at", 0) else b
    def new_order(s, tries=0, band=None):
        if MODE == "old": return s.new_order_old(tries)
        top = order_top(s.L); r = R.randrange(10); L = s.L
        gentle = s.served_ids < 6
        if gentle: top = 3
        band = 0 if gentle else (band if band is not None else s.next_band())
        if band == 0: n, lo, hi, odds = 1, max(2, top - 3), max(2, top - 2), 0; s.easy_at = s.t + EASY_GAP
        elif band == 2: n, lo, hi, odds = (1 if L < 2 else (3 if L >= 12 and r < 4 else 2)), max(2, top - 1), top, 2
        else: n, lo, hi, odds = (1 if L < 4 else (1 if r < 6 else 2)), max(2, top - 2), top, 4
        items = []
        alld = s.focus_dishes(); deep = [d for d in alld if is_deep(d)]; plain = [d for d in alld if not is_deep(d)]
        dishes = (deep or plain) if band == 2 else plain
        for _ in range(n):
            busy = any(any(chain_of(i) is None for i in o["items"]) for o in s.normal()) or any(chain_of(i) is None for i in items)
            if not gentle and odds and not busy and dishes and R.randrange(odds) == 0:
                items.append(R.choice(dishes)[0])
            else:
                used = [chain_of(i) for o in s.orders for i in o["items"] if chain_of(i)] + [chain_of(i) for i in items if chain_of(i)]
                m = min(used.count(k) for k in s.focus)
                k = R.choice([k for k in s.focus if used.count(k) == m])
                items.append(k + str(R.randint(lo, max(lo, hi))))
        if any(sorted(o["items"]) == sorted(items) for o in s.orders) and tries < 6: return s.new_order(tries + 1, band)
        v = sum(value(i) for i in items)
        if L >= 2 and not gentle and band < 2 and R.randrange(6) == 0 and not any(o["kind"] == "rush" for o in s.orders):
            return dict(items=items, stars=order_stars(v) * 2 + 1, kind="rush", until=s.t + 300, band=band)
        reg = L >= 3 and R.randrange(10) < 3
        return dict(items=items, stars=order_stars(v) + (1 if reg else 0), kind="normal", band=band)
    def ease(s):
        if MODE == "old": return
        # 回来时：难单留着当长目标；没有简单单的话，把一张中单换成简单的
        s.easy_at = 0
        if any(o.get("band") == 0 for o in s.normal()): return
        for k, o in enumerate(s.orders):
            if o["kind"] == "normal" and o.get("band") == 1 and not s.can_serve(o):
                s.orders[k] = s.new_order(band=0); s.stats["eased"] += 1; return
    def new_order_old(s, tries=0):
        top = order_top(s.L); r = R.randrange(10); L = s.L
        n = 1 if L < 2 else ((1 if r < 6 else 2) if L < 4 else (1 if r < 5 else (2 if (r < 9 or L < 12) else 3)))
        items = []
        dishes = s.focus_dishes()
        for _ in range(n):
            busy = any(any(chain_of(i) is None for i in o["items"]) for o in s.normal()) or any(chain_of(i) is None for i in items)
            if not busy and dishes and R.randrange(3) == 0:
                items.append(R.choice(dishes)[0])
            else:
                used = [chain_of(i) for o in s.orders for i in o["items"] if chain_of(i)] + [chain_of(i) for i in items if chain_of(i)]
                m = min(used.count(k) for k in s.focus)
                k = R.choice([k for k in s.focus if used.count(k) == m])
                items.append(k + str(R.randint(max(2, top - 2), top)))
        if any(sorted(o["items"]) == sorted(items) for o in s.orders) and tries < 6: return s.new_order_old(tries + 1)
        v = sum(value(i) for i in items)
        if L >= 2 and R.randrange(6) == 0 and not any(o["kind"] == "rush" for o in s.orders):
            return dict(items=items, stars=order_stars(v) * 2 + 1, kind="rush", until=s.t + 300)
        reg = L >= 3 and R.randrange(10) < 3
        return dict(items=items, stars=order_stars(v) + (1 if reg else 0), kind="normal")
    def can_serve(s, o):
        b = list(s.board)
        for it in o["items"]:
            if it not in b: return False
            b[b.index(it)] = None
        return True
    def needed(s):
        """订单还缺的东西（链 → 需要的最高级），菜 → 原料"""
        need = collections.defaultdict(int); dishes = []
        have = collections.Counter(x for x in s.board if x)
        for o in s.orders:
            for it in o["items"]:
                if have[it] > 0: have[it] -= 1; continue      # 台面上已经有了
                if chain_of(it): need[chain_of(it)] = max(need[chain_of(it)], tier(it))
                else: dishes.append(it)
        k = 0
        while k < len(dishes):
            d = dishes[k]; k += 1
            if d in s.board or any(v[0] == d for v in s.cook.values()): continue
            r = recipe(d)
            for n in r[2]:
                if have[n] > 0: have[n] -= 1; continue
                if chain_of(n): need[chain_of(n)] = max(need[chain_of(n)], tier(n))
                else: dishes.append(n)
        return need, dishes
    def sell_one(s, force=False):
        need, _ = s.needed()
        cand = [i for i in range(CELLS) if s.board[i] and chain_of(s.board[i]) and (force or tier(s.board[i]) > need.get(chain_of(s.board[i]), 0) or chain_of(s.board[i]) not in need)]
        if not cand: cand = [i for i in range(CELLS) if s.board[i] and chain_of(s.board[i])]
        c = min(cand, key=lambda i: tier(s.board[i])); s.board[c] = None; s.stats["sold"] += 1
        return c
    def gain_xp(s, n):
        s.xp += n
        while s.xp >= xp_need(s.L):
            s.xp -= xp_need(s.L); s.L += 1; s.gems += 3; s.energy = max(s.energy + 20, 100) if LVUP_FULL else s.energy + 20
            for k, u in CHAINS:
                if u == s.L: s.place_gen(k, 8 * COLS + 3)
            for a, u in APPL.items():
                if u == s.L:
                    c = s.empty(7 * COLS + 3) or s.sell_one(True); s.board[c] = a
    def step(s, day, newbie):
        s.act += 1
        # 冷却
        for c, g in s.gen.items():
            if g["refill"] and s.t >= g["refill"]: g["charges"] = 24; g["refill"] = None
        # 急单过期
        for k, o in enumerate(s.orders):
            if o["kind"] == "rush" and s.t >= o["until"]:
                s.rush_miss += 1; s.orders[k] = s.new_order(band=s.next_band(o)); return
        # 门单
        chapters = s.done // CH_LEN
        if s.served_ids >= 3 and not any(o["kind"] == "door" for o in s.orders) and s.lit < 14 and s.lit + 1 <= chapters + 1:
            it = "rice3" if s.lit == 0 else (R.choice(s.focus_dishes())[0] if s.focus_dishes() else R.choice(s.focus) + str(max(2, order_top(s.L) - 1)))
            s.orders.insert(0, dict(items=[it], stars=order_stars(value(it)) + 3, kind="door"))
        # 1 交单
        for o in s.orders:
            if s.can_serve(o):
                for it in o["items"]: s.board[s.board.index(it)] = None
                s.orders.remove(o); v = sum(value(i) for i in o["items"])
                s.stars += o["stars"]; s.gain_xp(ORDER_XP(v)); s.stats["served"] += 1; s.stats["served_" + o["kind"]] += 1; s.stats["band%s" % o.get("band", "-")] += 1; s.stats["deep"] += sum(1 for i in o["items"] if recipe(i) and is_deep(recipe(i))); s.stats["dish"] += sum(1 for i in o["items"] if recipe(i))
                if o["kind"] in ("normal", "first", "rush"):
                    s.served_ids += 1
                    for it in o["items"]: s.chain_ct[chain_of(it) or "dish"] += 1
                    s.items_ct.append(len(o["items"])); s.tier_ct += [tier(i) for i in o["items"] if chain_of(i)]
                    s.orders.append(s.new_order())
                if o["kind"] == "rush": s.rush_ok += 1
                if o["kind"] == "door": s.lit += 1; s.energy += 20
                return
        # 2 装修
        if s.done < len(TASKS) and s.stars >= TASKS[s.done]:
            s.stars -= TASKS[s.done]; s.gain_xp(TASKS[s.done] * 2); s.done += 1
            if s.done % CH_LEN == 0: s.boost_until = max(s.boost_until, s.t) + 30 * 60
            return
        need, dishes = s.needed()
        # 3 做菜 / 取菜
        for a, (d, at) in list(s.cook.items()):
            if s.t >= at and s.empty() is not None:
                s.board[s.empty()] = d; del s.cook[a]; return
        for d in dishes:
            if d in s.board or any(v[0] == d for v in s.cook.values()): continue
            r = recipe(d)
            if r[1] in s.board and r[1] not in s.cook and all(n in s.board for n in r[2]):
                for n in r[2]: s.board[s.board.index(n)] = None
                s.cook[r[1]] = (d, s.t + r[3] * 60); return
        # 4 合成（只合订单需要的链、到需要的级别；台子快满时什么都合）
        full = sum(1 for x in s.board if x) > CELLS - 6
        seen = {}
        for i, x in enumerate(s.board):
            if not x or not chain_of(x) or tier(x) >= 10: continue
            useful = full or tier(x) < need.get(chain_of(x), 0)
            if not useful: continue
            if x in seen:
                j = seen[x]; s.board[j] = None; s.board[i] = chain_of(x) + str(tier(x) + 1)
                if tier(x) + 1 >= MERGE_XP_TIER: s.gain_xp(1)
                s.stats["merge"] += 1; return
            seen[x] = i
        # 5 点产出器（台子挤了先卖用不上的）
        if s.empty() is None or (full and any(x and chain_of(x) and chain_of(x) not in need for x in s.board)): s.sell_one(); return
        if not newbie and s.energy < 1: s.idle += 1; return
        gens = sorted(s.gen.items(), key=lambda kv: (-need.get(kv[1]["chain"], 0), R.random()))
        for c, g in gens:
            if need.get(g["chain"], 0) == 0 and not full: continue
            if g["charges"] <= 0:
                if newbie: g["charges"] = 24; g["refill"] = None
                else: continue
            e = s.empty(c)
            t = 1 if R.random() < 0.9 else 2
            s.board[e] = g["chain"] + str(t); g["charges"] -= 1
            if g["charges"] == 0: g["refill"] = s.t + 20 * 60
            if not newbie: s.energy -= 1
            s.stats["tap"] += 1; return
        s.idle += 1

def quiet(days=84, sessions=3, mins=12, sec_per_act=2.0):
    """不打印：返回 到第 n 件装修是第几天、平均空等、第 7/28 天等级"""
    g = G(); reach = {}; idle = []; lv = {}
    for d in range(1, days + 1):
        g.refresh_focus(d); i0, a0 = g.idle, g.act; g.free_refills_today = 0
        for _ in range(sessions):
            g.t += 4 * 3600; g.energy = min(100, g.energy + int(4 * 3600 / REGEN)); end = g.t + mins * 60
            if _ == 0: g.boost_until = max(g.boost_until, g.t) + (60 if d == 1 else 30) * 60
            g.ease()
            while g.t < end:
                g.step(d, newbie=g.t < g.boost_until); g.t += sec_per_act
                if g.energy < 100: g.energy = min(100, g.energy + sec_per_act / REGEN)
        for m in (6, 12, 24, 48, 72, 84):
            if g.done >= m and m not in reach: reach[m] = d
        if d > 3: idle.append((g.idle - i0) / max(1, g.act - a0))
        lv[d] = g.L
    return reach, round(100 * sum(idle) / max(1, len(idle))), lv[1], lv[7], lv[28]

def run(days=21, sessions=3, mins=12, sec_per_act=2.0):
    g = G()
    print("天 | 级 | 交单 | 装修 | 章 | 门单亮 | 急单赶上/错过 | 空等% | 单子链占比（今天） | 平均几样 | 平均几级")
    for d in range(1, days + 1):
        g.refresh_focus(d); g.free_refills_today = 0; before = dict(g.stats); g.chain_ct.clear(); g.items_ct.clear(); g.tier_ct.clear()
        ro, rm, idle0, act0 = g.rush_ok, g.rush_miss, g.idle, g.act
        for sidx in range(sessions):
            g.t += 4 * 3600   # 两次开店之间 4 小时：冷却回满、体力回满、菜做好
            g.energy = min(100, g.energy + int(4 * 3600 / 90))
            end = g.t + mins * 60
            if sidx == 0: g.boost_until = max(g.boost_until, g.t) + (60 if d == 1 else 30) * 60
            g.ease()
            while g.t < end:
                g.step(d, newbie=g.t < g.boost_until); g.t += sec_per_act
        served = g.stats["served"] - before.get("served", 0)
        tot = sum(g.chain_ct.values()) or 1
        mix = " ".join(f"{k}{round(100 * v / tot)}%" for k, v in g.chain_ct.most_common(5))
        avg_n = sum(g.items_ct) / max(1, len(g.items_ct)); avg_t = sum(g.tier_ct) / max(1, len(g.tier_ct))
        idle = round(100 * (g.idle - idle0) / max(1, g.act - act0))
        print(f"{d:2d} | {g.L:2d} | {served:3d} | {g.done:2d}/84 | {g.done // CH_LEN + 1:2d} | {g.lit:2d} | {g.rush_ok - ro}/{g.rush_miss - rm} | {idle:3d} | {mix} | {avg_n:.2f} | {avg_t:.1f}")

if __name__ == "__main__":
    run()
