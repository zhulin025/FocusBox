#!/bin/bash

# FocusBox 构建脚本

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="FocusBox"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "🔨 构建 FocusBox..."

# 创建应用目录结构
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 编译 Swift 代码
echo "📦 编译 Swift 代码..."
swiftc \
    -o "$APP_PATH/Contents/MacOS/$APP_NAME" \
    -sdk $(xcrun --show-sdk-path) \
    -target x86_64-apple-macos12.0 \
    -framework AppKit \
    -framework SwiftUI \
    "$PROJECT_DIR/FocusBoxApp.swift" \
    "$PROJECT_DIR/OverlayWindow.swift" \
    "$PROJECT_DIR/MouseMonitor.swift"

# 创建 Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FocusBox</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.FocusBox</string>
    <key>CFBundleName</key>
    <string>FocusBox</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <!-- <key>LSUIElement</key> -->
    <!-- <true/> -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 设置可执行权限
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "✅ 构建完成！"
echo "📍 应用位置：$APP_PATH"
echo ""
echo "⚠️  首次运行需要辅助功能权限："
echo "   系统设置 → 隐私与安全性 → 辅助功能 → 添加 FocusBox"
echo ""
echo "🚀 运行应用：open $APP_PATH"
