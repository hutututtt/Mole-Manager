#!/bin/bash
set -e

# Configuration
APP_NAME="Mole"
# Get the actual build path dynamically
BUILD_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
APP_BUNDLE="$APP_NAME.app"
ICON_SOURCE="Sources/Mole/Resources/mole.png"

echo "🚀 Building Release Binary..."
swift build -c release

echo "📦 Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "📄 Copying Executable..."
cp "$BUILD_PATH" "$APP_BUNDLE/Contents/MacOS/"

echo "📝 Generatign Info.plist..."
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.tw93.mole</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Generating App Icon from $ICON_SOURCE..."
    ICONSET="Mole.iconset"
    mkdir -p "$ICONSET"

    # Resize images for standard icon sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

    # Convert to icns
    iconutil -c icns "$ICONSET"
    mv "Mole.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

    # Clean up
    rm -rf "$ICONSET"

    echo "✅ App Icon set successfully."
else
    echo "⚠️ Icon file not found at $ICON_SOURCE. App will use default icon."
fi

# Remove xattr com.apple.quarantine to avoid warnings
xattr -cr "$APP_BUNDLE"

echo "✅ App Packaged: $APP_BUNDLE"
echo "👉 You can now move $APP_NAME.app to /Applications"
