#!/bin/bash
# Compiles and runs the checks in tools/tests (they only read; nothing is removed).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -swift-version 5 Sources/Core.swift Sources/Localization.swift tools/tests/main.swift -o build/tests
build/tests
