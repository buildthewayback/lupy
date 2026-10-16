#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lupy-wake.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/Voice/WakePhrase.swift Mac/Tests/lupy/WakeLupyTests.swift -o "$TEST_DIR/wake-lupy-tests"
"$TEST_DIR/wake-lupy-tests"
