#!/usr/bin/env bash
# 一键打包 Android APK：Godot 导出未签名 release 包 → tools/sign_apk.py 对齐并做 v2 签名。
# 需要：Godot 4.4.1 + 导出模板；编辑器设置里的 Android SDK 路径需存在 platform-tools/adb 与 build-tools/*/apksigner
# （没有 SDK 时放两个空脚本即可通过 Godot 的检查，签名由 sign_apk.py 完成）。
# 用法：tools/build_android.sh [密钥库] [别名] [密码]，默认用 Godot 的 debug.keystore。
set -euo pipefail
cd "$(dirname "$0")/.."
KS="${1:-$HOME/.local/share/godot/keystores/debug.keystore}"
ALIAS="${2:-androiddebugkey}"
PASS="${3:-android}"
mkdir -p export
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Android" export/shenkong-otome-unsigned.apk
python3 tools/sign_apk.py export/shenkong-otome-unsigned.apk export/shenkong-otome.apk --keystore "$KS" --alias "$ALIAS" --pass "$PASS"
rm -f export/shenkong-otome-unsigned.apk
ls -lh export/shenkong-otome.apk
