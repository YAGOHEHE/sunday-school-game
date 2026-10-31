#!/bin/bash
# Compila en release y ensambla build/Juegos Dominical.app (firma ad-hoc).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d ' \n' < "$ROOT/VERSION")"
NAME="Juegos Dominical"
APP="$ROOT/build/$NAME.app"

cd "$ROOT/App"
swift build -c release --product JuegosMac
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/JuegosMac" "$APP/Contents/MacOS/$NAME"
# Recursos de SwiftPM (games.json). Catalog.loadBundled lo busca en Contents/Resources.
cp -R "$BIN_DIR/JuegosDominical_JuegosCore.bundle" "$APP/Contents/Resources/"
cp -R "$BIN_DIR/JuegosDominical_JuegosUI.bundle" "$APP/Contents/Resources/"   # fuentes (Fredoka)

ICON_KEY=""
if [ -f "$ROOT/App/Icon/Juegos.icns" ]; then
  cp "$ROOT/App/Icon/Juegos.icns" "$APP/Contents/Resources/Juegos.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>Juegos</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>org.escueladominical.juegos</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  $ICON_KEY
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"
codesign -dv "$APP" 2>&1 | head -5 || true
echo "OK: $APP"
