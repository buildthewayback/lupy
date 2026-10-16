#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-shortcuts.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/ShortcutLogic.swift \
    Mac/Tests/coucou/ShortcutTests.swift -o "$TEST_DIR/shortcut-tests"
"$TEST_DIR/shortcut-tests"
