#!/bin/bash
# 商店截图：模拟器 + 截图模式（-shot）。中英各一套。由 codemagic 的 screenshots 工作流手动触发。
set -x
DEV=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[(rt,x) for rt,xs in d.items() if "iOS" in rt for x in xs if "Pro Max" in x["name"]]
c.sort(key=lambda t:(t[0],t[1]["name"]))
print(c[-1][1]["udid"])')
echo "device $DEV"
xcrun simctl boot "$DEV" || true
xcrun simctl bootstatus "$DEV" -b
xcodebuild -project IslandMe.xcodeproj -scheme IslandMe -configuration Debug -sdk iphonesimulator \
  -destination "id=$DEV" -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" | head -30
APP=$(find build/dd/Build/Products -maxdepth 2 -name "IslandMe.app" | head -1)
echo "app $APP"
xcrun simctl install "$DEV" "$APP"
xcrun simctl ui "$DEV" appearance dark
xcrun simctl status_bar "$DEV" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
mkdir -p shots
BID=com.eddiejiang.islandme
shot() {
  local lang=$1 loc=$2 name=$3; shift 3
  xcrun simctl terminate "$DEV" $BID 2>/dev/null || true
  xcrun simctl terminate "$DEV" com.apple.Preferences 2>/dev/null || true
  xcrun simctl launch "$DEV" $BID -shot -AppleLanguages "($lang)" -AppleLocale "$loc" "$@"
  sleep 10
  xcrun simctl io "$DEV" screenshot "shots/${lang}_${name}.png"
}
for pair in "zh-Hans zh_CN" "en en_US"; do
  set -- $pair; L=$1; LOC=$2
  shot $L $LOC 1_home -shotTab 0
  shot $L $LOC 2_kitchen -shotTab 4
  shot $L $LOC 3_story -shotTab 4 -shotScene 12
  shot $L $LOC 4_nest -shotTab 1
  shot $L $LOC 5_store -shotTab 2 -shotShop 1
  shot $L $LOC 6_map -shotTab 4 -shotMap
  # 2026-10-22 新增：装修全做完（温泉小院那一页）、小游戏（猜杯子，玩到一半）
  xcrun simctl terminate "$DEV" $BID 2>/dev/null || true
  xcrun simctl launch "$DEV" $BID -demoKitchen -demoAllDone -demoSheet deco -AppleLanguages "($L)" -AppleLocale "$LOC"
  sleep 12; xcrun simctl io "$DEV" screenshot "shots/${L}_7_hotspring.png"
  xcrun simctl terminate "$DEV" $BID 2>/dev/null || true
  xcrun simctl launch "$DEV" $BID -shot -shotTab 0 -shotGame cups -shotAutoStart -AppleLanguages "($L)" -AppleLocale "$LOC"
  sleep 4; xcrun simctl io "$DEV" screenshot "shots/${L}_8_games.png"
  # 灵动岛：App 开着时开始实时活动，切到设置 App，岛上就是嘟嘟
  shot $L $LOC 7_pre -shotTab 0
  sleep 6
  xcrun simctl launch "$DEV" com.apple.Preferences; sleep 10
  xcrun simctl io "$DEV" screenshot "shots/${L}_7_island.png"
done
ls -la shots
