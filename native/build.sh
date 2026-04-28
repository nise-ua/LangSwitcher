#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

APP="LangSwitcher.app"
BIN="$APP/Contents/MacOS/LangSwitcher"

echo "🔨 Compiling…"
clang -framework Cocoa -framework Carbon -framework ApplicationServices \
      -fobjc-arc -O2 \
      -o LangSwitcher main.m

echo "📦 Bundling .app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv LangSwitcher "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"

echo "✍️  Ad-hoc signing…"
codesign --force --sign - --deep "$APP"

echo ""
echo "✅  Built: $DIR/$APP"
echo ""
echo "First launch:"
echo "  open '$DIR/$APP'"
echo ""
echo "Then: System Settings → Privacy & Security → Accessibility → LangSwitcher ✓"
