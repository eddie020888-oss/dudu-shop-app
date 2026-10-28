#!/bin/bash
# 自测（Codemagic「自测（手动）」工作流）：模拟器里
#  1) 新玩家第一次打开：开场故事 4 页 + 开蛋，按时间截图
#  2) 小店中期 / 后期（-demoLate：12 级、大订单、深菜、新食材）+ 图鉴、任务页截图，中英各一
#  3) 机器人用真代码从新开局玩 120 天，出报告 selftest.txt
set -x
DEV=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[(rt,x) for rt,xs in d.items() if "iOS" in rt for x in xs if "Pro Max" in x["name"]]
c.sort(key=lambda t:(t[0],t[1]["name"]))
print(c[-1][1]["udid"])')
xcrun simctl boot "$DEV" || true
xcrun simctl bootstatus "$DEV" -b
xcodebuild -project IslandMe.xcodeproj -scheme IslandMe -configuration Debug -sdk iphonesimulator \
  -destination "id=$DEV" -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning: unre|BUILD" | head -40
APP=$(find build/dd/Build/Products -maxdepth 2 -name "IslandMe.app" | head -1)
[ -f "$APP/Info.plist" ] || { echo "编译失败，看上面的 error:"; exit 1; }
BID=com.eddiejiang.islandme
mkdir -p selftest
xcrun simctl ui "$DEV" appearance dark
fresh() { xcrun simctl uninstall "$DEV" $BID 2>/dev/null; xcrun simctl install "$DEV" "$APP"; }
cap() { xcrun simctl io "$DEV" screenshot "selftest/$1.png"; }

# 省钱：默认只跑机器人；要截图时在 Codemagic 里加环境变量 SHOTS=1
if [ "${SHOTS:-0}" = "1" ]; then
# 1) 新玩家
fresh
xcrun simctl launch "$DEV" $BID -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN
for t in 1 2 3 4 5 6; do sleep 5; cap "1_new_${t}"; done
PID=$(pgrep -f "IslandMe.app/IslandMe" | head -1); [ -n "$PID" ] && sample "$PID" 3 -file selftest/sample_story.txt >/dev/null 2>&1
# 对照：同样新玩家，但不碰音频
fresh
xcrun simctl launch "$DEV" $BID -noAudio -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN
for t in 1 2 3; do sleep 5; cap "1b_new_noaudio_${t}"; done
# 主页（老玩家路径）+ 小店标签页（真实路径，不是 demo）
run0() { xcrun simctl terminate "$DEV" $BID 2>/dev/null || true; xcrun simctl launch "$DEV" $BID -shot -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN "$@"; sleep 12; }
run0 -shotTab 0; cap 1_home_shot
run0 -shotTab 4; cap 1_kitchen_shot
xcrun simctl spawn "$DEV" log show --last 3m --style compact --predicate 'process == "IslandMe" AND (messageType == error OR messageType == fault)' > selftest/app_errors.log 2>&1 || true

# 2) 小店：中期、后期、图鉴、任务
run() {
  local lang=$1 loc=$2 name=$3; shift 3
  xcrun simctl terminate "$DEV" $BID 2>/dev/null || true
  xcrun simctl launch "$DEV" $BID -AppleLanguages "($lang)" -AppleLocale "$loc" "$@"
  sleep 12; cap "${name}_${lang}"
}
for pair in "zh-Hans zh_CN" "en en_US"; do
  set -- $pair
  run $1 $2 2_shop_mid -demoKitchen
  PID=$(pgrep -f "IslandMe.app/IslandMe" | head -1); [ -n "$PID" ] && sample "$PID" 3 -file selftest/sample_demo_$1.txt >/dev/null 2>&1
  run $1 $2 2b_shop_mid_noaudio -demoKitchen -noAudio
  run $1 $2 3_shop_late -demoKitchen -demoLate
  run $1 $2 4_book_late -demoKitchen -demoLate -demoSheet book
  run $1 $2 5_tasks -demoKitchen -demoSheet tasks
done
# 2026-10-21 新内容：装修全做完（最后一片温泉小院 + 下一站）、季卡、商城饰品
run zh-Hans zh_CN 6_deco_alldone -demoKitchen -demoAllDone -demoSheet deco
run zh-Hans zh_CN 6b_deco -demoKitchen -demoLate -demoSheet deco
run zh-Hans zh_CN 6c_season -demoKitchen -demoSheet season
run zh-Hans zh_CN 8_gemshop -demoKitchen -demoSheet gems
run en en_US 8_gemshop -demoKitchen -demoSheet gems
run en en_US 6_deco_alldone -demoKitchen -demoAllDone -demoSheet deco
# 小游戏：首页「快乐」点开的挑游戏页 + 每个游戏开局 2 秒、6 秒各一张
run0 -shotTab 0 -shotPickGame; cap 7_pick_game
for g in fling cups dudu match coins stars; do
  xcrun simctl terminate "$DEV" $BID 2>/dev/null || true
  xcrun simctl launch "$DEV" $BID -shot -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN -shotTab 0 -shotGame $g -shotAutoStart
  sleep 7; cap "7_game_${g}_a"; sleep 3; cap "7_game_${g}_b"
done

fi
# 3) 机器人（只跑机器人时也要先装上 App）
[ "${SHOTS:-0}" = "1" ] || fresh
xcrun simctl terminate "$DEV" $BID 2>/dev/null || true
xcrun simctl launch "$DEV" $BID -demoKitchen -demoFresh -selfTest -selfTestDays 40 -selfTestRuns 2 -selfTestHuman -selfTestLuck 0.1 -noAudio -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN
DATA=$(xcrun simctl get_app_container "$DEV" $BID data)
for i in $(seq 1 180); do [ -f "$DATA/Documents/selftest.txt" ] && break; pgrep -f "IslandMe.app/IslandMe" >/dev/null || { echo "app exited"; break; }; sleep 10; done
cp "$DATA/Documents/selftest.txt" selftest/ 2>/dev/null || echo "no report"
cp "$DATA/Documents/selftest_progress.txt" selftest/ 2>/dev/null || true
# 闪退报告
find ~/Library/Logs/DiagnosticReports -name "IslandMe*" -mmin -60 -exec cp {} selftest/ \; 2>/dev/null || true
cap 6_bot
ls -la selftest
