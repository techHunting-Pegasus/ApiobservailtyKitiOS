#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/APIObservabilityKit.xcodeproj"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_PATH="${1:-$BUILD_DIR/APIObservabilityKit.xcframework}"

if [[ -e "$OUTPUT_PATH" ]]; then
    printf 'Output already exists: %s\nRemove it before rebuilding.\n' "$OUTPUT_PATH" >&2
    exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/api-observability-kit.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme APIObservabilityKit \
    -configuration Release \
    -derivedDataPath "$TEMP_DIR/DerivedData" \
    -destination "generic/platform=iOS" \
    -archivePath "$TEMP_DIR/iOS.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO

xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme APIObservabilityKit \
    -configuration Release \
    -derivedDataPath "$TEMP_DIR/DerivedData" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$TEMP_DIR/iOS-Simulator.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO

xcodebuild -create-xcframework \
    -framework "$TEMP_DIR/iOS.xcarchive/Products/Library/Frameworks/APIObservabilityKit.framework" \
    -framework "$TEMP_DIR/iOS-Simulator.xcarchive/Products/Library/Frameworks/APIObservabilityKit.framework" \
    -output "$TEMP_DIR/APIObservabilityKit.xcframework"

mkdir -p "$(dirname "$OUTPUT_PATH")"
mv "$TEMP_DIR/APIObservabilityKit.xcframework" "$OUTPUT_PATH"
printf 'Created %s\n' "$OUTPUT_PATH"
