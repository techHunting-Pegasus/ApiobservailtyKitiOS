#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/api-observability-tests.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
cd "$PROJECT_ROOT"

# Compile the production networking code on macOS, substituting only UIKit's
# device metadata. HTTP requests run against a local echo server.
xcrun swiftc -swift-version 5 -module-cache-path "$TEMP_DIR/module-cache" \
    APIObservabilityKit/APIObservability.swift \
    APIObservabilityKit/APINetworkInfo.swift \
    APIObservabilityKit/Configuration/*.swift \
    APIObservabilityKit/Networking/*.swift \
    APIObservabilityKit/Models/*.swift \
    APIObservabilityKit/Security/*.swift \
    APIObservabilityKit/Storage/*.swift \
    APIObservabilityKit/Upload/*.swift \
    Tests/Support/DeviceInfo.swift Tests/NetworkingRegressionTests.swift \
    -o "$TEMP_DIR/networking-tests"
python3 Tests/run_networking_server.py "$TEMP_DIR/networking-tests"
