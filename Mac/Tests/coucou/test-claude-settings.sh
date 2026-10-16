#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-claude-settings.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/ClaudeSettingsFile.swift \
    Mac/Tests/coucou/ClaudeSettingsFileTests.swift -o "$TEST_DIR/claude-settings-tests"
"$TEST_DIR/claude-settings-tests"
