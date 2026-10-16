#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-safe-links.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/SafeWebURL.swift \
    Mac/Tests/coucou/SafeWebURLTests.swift -o "$TEST_DIR/safe-links-tests"
"$TEST_DIR/safe-links-tests"
