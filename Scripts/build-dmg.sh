#!/bin/bash
#
# 构建 Release 通用包（arm64 + x86_64）并打包为可拖拽安装的 DMG。
#
# 本机没有 Developer ID 证书，因此使用 ad-hoc 签名并关闭 Hardened Runtime。
# 产物未公证，只适合本机或可信设备安装。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

PROJECT="$ROOT/eul.xcodeproj"
SCHEME="eul"
DERIVED="$ROOT/DerivedData"
APP="$DERIVED/Build/Products/Release/eul.app"
DIST="$ROOT/dist"

echo "==> 解析依赖"
xcodebuild \
    -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED" \
    -onlyUsePackageVersionsFromResolvedFile

echo "==> 构建 Release"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" \
    -disableAutomaticPackageResolution \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM="" \
    ONLY_ACTIVE_ARCH=NO \
    ENABLE_HARDENED_RUNTIME=NO \
    build

# LaunchAtLogin 4.2.0 的复制脚本在 CODE_SIGN_ENTITLEMENTS 非空时会用
# "Sign to Run Locally" 签名 helper，该名称对 codesign 无效，且脚本随后修改了
# Info.plist，导致嵌套签名无效。这里用 ad-hoc 重新签名 helper。
HELPER="$APP/Contents/Library/LoginItems/LaunchAtLoginHelper.app"
HELPER_ENT="$DERIVED/SourcePackages/checkouts/LaunchAtLogin/Sources/LaunchAtLogin/LaunchAtLogin.entitlements"

echo "==> 修复 LaunchAtLogin helper 签名"
codesign --force --sign - --entitlements "$HELPER_ENT" "$HELPER"

# helper 的签名变化后，需要更新外层 app 的封装。
echo "==> 重新签名 eul.app"
codesign --force --sign - --entitlements "$ROOT/eul/eul.entitlements" "$APP"
codesign --verify --deep --strict "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/eul-$VERSION.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/eul-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

echo "==> 制作 DMG"
ditto "$APP" "$STAGE/eul.app"
ln -s /Applications "$STAGE/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
xcrun SetFile -a C "$STAGE" 2>/dev/null || true

mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create -volname "eul" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
cat "$DMG.sha256"

echo "==> 完成：$DMG"
