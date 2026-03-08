#!/bin/bash
# build.sh
APP_NAME="PlannerCapture"
APP_DIR="$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

# --- Version resolution ---
# Public version: read from VERSION file (e.g. 3.1.0)
APP_VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]')
if [ -z "$APP_VERSION" ]; then
    echo "Warning: VERSION file missing or empty; defaulting to 0.0.0"
    APP_VERSION="0.0.0"
fi

# Build number: auto-generated from total git commit count
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "0")

echo "Building $APP_NAME v$APP_VERSION (build $BUILD_NUMBER)..."

mkdir -p "$BIN_DIR"
mkdir -p "$RES_DIR"

# Create Info.plist for UIElement app
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PlannerCapture</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.PlannerCapture</string>
    <key>CFBundleName</key>
    <string>PlannerCapture</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleGetInfoString</key>
    <string>PlannerCapture $APP_VERSION (build $BUILD_NUMBER)</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

swiftc Sources/*.swift -o "$BIN_DIR/$APP_NAME"
if [ $? -eq 0 ]; then
    echo "Successfully built $APP_DIR"
else
    echo "Build failed"
    exit 1
fi
