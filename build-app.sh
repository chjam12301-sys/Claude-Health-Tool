#!/usr/bin/env bash
# Assemble Claudoctor.app from the SPM release build.
# Requires macOS + Xcode/Swift toolchain. Run on a Mac:
#   ./build-app.sh
set -euo pipefail

CONFIG="release"
APP_NAME="Claudoctor"
BUNDLE_ID="com.sunnycao.claudoctor"
BUILD_DIR=".build/${CONFIG}"
APP_DIR="${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Info.plist" "${APP_DIR}/Contents/Info.plist"

echo "==> Done: ${APP_DIR}"
echo "Launch with: open ${APP_DIR}"
echo "Note: first launch will prompt for Automation + Notification permissions."
