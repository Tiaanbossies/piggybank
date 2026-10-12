#!/usr/bin/env bash
# Builds the signed release AAB + APK with Dart obfuscation enabled.
#
# R8/ProGuard (android/app/build.gradle.kts + proguard-rules.pro) only covers the Kotlin/Java
# Android-embedding layer. Dart code itself needs a separate --obfuscate flag, or the release
# binary ships with readable Dart class/method/symbol names. --split-debug-info writes the
# symbol map needed to de-obfuscate a real crash's stack trace back to Dart source later — keep
# that output, it's needed for every future crash report against this exact build.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
SYMBOLS_DIR="build/symbols/${VERSION}"

# Shown in Settings -> About ("built 12 Oct 2026"); see lib/core/app/app_build.dart.
BUILD_DATE=$(date -u +%F)

echo "Building release AAB + APK for version ${VERSION} (${BUILD_DATE}), symbols -> ${SYMBOLS_DIR}"
mkdir -p "$SYMBOLS_DIR"

flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOLS_DIR" --dart-define=BUILD_DATE="$BUILD_DATE"
# Universal APK, not --split-per-abi: a split APK's versionCode carries 1000 x the
# ABI number (arm64 build 9 reports 2009). The app copes (AppBuild.buildNumber),
# but publish_release.sh ships this universal file.
flutter build apk --release --obfuscate --split-debug-info="$SYMBOLS_DIR" --dart-define=BUILD_DATE="$BUILD_DATE"

echo
echo "Done. Back up ${SYMBOLS_DIR} outside the repo (e.g. alongside the release keystore in"
echo "'Piggybank - Ops/') before discarding this build directory — without it, a crash report"
echo "from this exact release build can't be symbolicated back to readable Dart source."
