#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-desktop.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/DesktopMochiLogic.swift \
    Mac/Tests/coucou/DesktopMochiTests.swift -o "$TEST_DIR/desktop-mochi-tests"
"$TEST_DIR/desktop-mochi-tests"
