#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-claude-hooks.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/ClaudeHookDetection.swift \
    Mac/Tests/coucou/ClaudeHookDetectionTests.swift -o "$TEST_DIR/claude-hooks-tests"
"$TEST_DIR/claude-hooks-tests"
