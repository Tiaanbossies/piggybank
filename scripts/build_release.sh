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

echo "Building release AAB + APK for version ${VERSION}, symbols -> ${SYMBOLS_DIR}"
mkdir -p "$SYMBOLS_DIR"

flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOLS_DIR"
flutter build apk --release --obfuscate --split-debug-info="$SYMBOLS_DIR"

echo
echo "Done. Back up ${SYMBOLS_DIR} outside the repo (e.g. alongside the release keystore in"
echo "'Piggybank - Ops/') before discarding this build directory — without it, a crash report"
echo "from this exact release build can't be symbolicated back to readable Dart source."
