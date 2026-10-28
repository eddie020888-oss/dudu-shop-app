# 嘟嘟小店 · English translation guide

App: "Dudu Shop" — an iPhone virtual pet that lives in the Dynamic Island, plus a cozy merge-cooking shop game. Audience: casual adults. Tone: warm, cozy, gently funny.

## The pet: Dudu
A small, round, very lazy purple creature from Planet Dudu. Short arms. Always lying down; puts things on its tummy. Speaks in short, sleepy, deadpan lines. Never demanding, never guilt-trips the player. Companion, not a nag.
Good: "Just put the coins on my tummy." / "I'm not lazy. I'm on Dudu time." / "You go. I'll ride my skateboard behind you."
Avoid: exclamation spam, slang that will age, anything cutesy-baby-talk.

## Glossary (use exactly)
嘟嘟 (pet) = Dudu · 小紫 (old name of the pet) = Dudu · 芋圆 = Dudu
嘟嘟小店 = Dudu Shop · 小店 (tab / the shop) = Shop · 总店 = the main shop · 分店 = the branch
嘟嘟星 = Planet Dudu · 嘟嘟语 = Dudu-speak · 嘟 / 嘟嘟 (sound it makes) = doo / doo-doo
星星爷爷 = Grandpa Star · 小徒弟 = little apprentice · 门 / 那道门 = the Door · 门单 = door order · 门缝 = the crack in the Door
灵动岛 = Dynamic Island · 岛台 / 岛 = the island · 锁屏 = Lock Screen · 实时活动 = Live Activity
首页 = Home · 窝 = Nest · 商城 = Store · 我 (tab) = Me · 背包 = Bag · 图鉴 = Collection · 目标 = Goals · 装修 = Decorate (noun: renovation) · 小铺 = Market · 线索本 = Clue Book
外卖 = Delivery · 急单 = Rush order · 今日招牌 = Today's Special · 熟客 = regulars · 小票 = ticket
体力 = Energy · 宝石 = gems · 星星 / ★ = stars · 币 = coins · 产出器 = generator · 厨具 = appliance · 宝箱 = chest · 拍立得 = Polaroid · 心愿 = wish · 合成 = merge · 交 (order button) = Serve
谜底揭晓 = Mystery solved · 揭了一角 = A corner lifted · 来信 = letter
District names: 饭团湾 Riceball Bay · 汤锅镇 Soup Pot Town · 米仓坡 Rice Barn Hill · 蜂蜜谷 Honey Valley · 胡萝卜原 Carrot Fields · 睡莲湖 Lily Lake · 茶雾山 Tea Mist Mountain · 月亮渡口 Moon Ferry · 星星集市 Star Market · 灯塔岬 Lighthouse Cape · 雪绒岭 Snowfluff Ridge · 光之泉 Fountain of Light · 石头屋 stone house
Regulars: 灯塔 the Lighthouse · 图书馆 the Library · 花店楼上 Above the Flower Shop · 学校门口 School Gate · 河边公寓 Riverside Apartments
{0} 级 = Lv {0} · 第 {0} 章 = Chapter {0} · {0} 步 = {0} steps

## Rules
- Keep every placeholder {0} {1} … exactly (you may reorder them). Keep emoji, ★, ⏱, 🌙, \n (newlines) and \" escapes as they are.
- Chinese quotes 「」 “” → English double quotes “ ” (curly). Chinese punctuation → English punctuation. “……” → “…”.
- UI labels (short Chinese, 1–4 characters, buttons/tabs/titles): keep them short — ideally ≤ 12 characters.
- Strings starting/ending with spaces or " · " separators: keep the same leading/trailing spaces/separators.
- Food & item names: natural, appetizing, title-case only for proper names (e.g. "Strawberry Cake", "Rice Ball Trio").
- If a string is pure Dudu-speak (only 嘟 / punctuation / symbols), render it as doo-speak keeping rhythm: "嘟嘟？嘟。" → "Doo-doo? Doo."
- Never translate literally when it reads awkwardly; translate the meaning in Dudu's voice.
- Output: a single JSON object {"<exact Chinese key>": "<English>", …} containing EVERY key from your input file, nothing else.
