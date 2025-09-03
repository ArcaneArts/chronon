#!/bin/bash

SDK_VERSION="3.9.2"
PLATFORM="macos"
ARCH="arm64"
ZIP_URL="https://storage.googleapis.com/dart-archive/channels/stable/release/${SDK_VERSION}/sdk/dartsdk-${PLATFORM}-${ARCH}-release.zip"
BASE_DIR="$(pwd)"
TEMP_DIR="$BASE_DIR/data"
PROJECT_DIR="$BASE_DIR/projects/chronon_helm"
ENTRY_POINT="bin/chronon_helm.dart"
DART_BIN="$TEMP_DIR/dart-sdk/bin/dart"

echo "Current directory: $BASE_DIR"
echo "Checking for Dart binary at: $DART_BIN"
ls -l "$DART_BIN" 2>/dev/null || echo "Dart binary not found or inaccessible"

if [ -f "$DART_BIN" ] && [ -x "$DART_BIN" ]; then
    echo "Dart SDK found at $TEMP_DIR/dart-sdk"
else
    echo "Downloading Dart SDK..."
    curl -L -o dart_sdk.zip "$ZIP_URL" || exit 1
    echo "Extracting SDK..."
    mkdir -p "$TEMP_DIR"
    unzip -q dart_sdk.zip -d "$TEMP_DIR" || exit 1
    if [ ! -f "$DART_BIN" ]; then
        echo "Error: Dart binary not found at $DART_BIN after extraction"
        exit 1
    fi
    chmod +x "$DART_BIN"
    rm -rf dart_sdk.zip
fi

echo "Verifying Dart SDK version..."
"$DART_BIN" --version || exit 1
echo "Fetching dependencies..."
cd "$PROJECT_DIR" || exit 1
"$DART_BIN" pub get || exit 1
cd - || exit 1
echo "Pulling Images..."
docker compose build
echo "Running Dart project..."
cd "$PROJECT_DIR" || exit 1
if [ -f "$ENTRY_POINT" ]; then
    "$DART_BIN" run "$ENTRY_POINT" || exit 1
else
    echo "Error: Entry point not found at $PROJECT_DIR/$ENTRY_POINT"
    exit 1
fi