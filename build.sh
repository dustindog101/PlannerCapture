#!/bin/bash
# build.sh
APP_NAME="PlannerCapture"
APP_DIR="$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

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
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Compiling Swift files..."
swiftc Sources/*.swift -o "$BIN_DIR/$APP_NAME"
if [ $? -eq 0 ]; then
    echo "Successfully built $APP_DIR"
else
    echo "Build failed"
    exit 1
fi
