#!/bin/bash
# key-renda-kidou の .app バンドルをビルドするスクリプト
#
# 使い方:
#   scripts/build-app.sh            → build/key-renda-kidou.app を作成
#   scripts/build-app.sh --install  → 作成後 ~/Applications にコピーして起動
#
# Xcode不要（コマンドラインツールのみでビルド可能）

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="key-renda-kidou"
APP_DIR="build/${APP_NAME}.app"

echo "▶ リリースビルドを実行中..."
swift build -c release

echo "▶ .appバンドルを組み立て中..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/KeyRendaKidou" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "scripts/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "scripts/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "▶ 署名中（ad-hoc署名）..."
codesign --force --sign - --identifier "com.johosauce.key-renda-kidou" "$APP_DIR"

echo "✅ 完成: $APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"

    # 起動中なら終了してから差し替える
    if pgrep -x "$APP_NAME" > /dev/null; then
        echo "▶ 起動中のアプリを終了します..."
        pkill -x "$APP_NAME" || true
        sleep 1
    fi

    rm -rf "$INSTALL_DIR/${APP_NAME}.app"
    cp -R "$APP_DIR" "$INSTALL_DIR/"
    echo "✅ インストール完了: $INSTALL_DIR/${APP_NAME}.app"

    echo "▶ アプリを起動します..."
    open "$INSTALL_DIR/${APP_NAME}.app"
    echo ""
    echo "【注意】再ビルド後は署名が変わるため、「入力監視」の許可が効かなくなった場合は"
    echo "システム設定 → 入力監視 で key-renda-kidou を一度オフ→オンしてください。"
    echo "それでも直らない場合のみ「−」で削除 →「＋」で追加し直してください。"
    echo "（tccutil reset は手動追加した許可も消してしまうため自動実行しない）"
fi
