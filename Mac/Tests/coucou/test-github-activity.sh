#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-github-activity.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/GitHubActivity.swift \
    Mac/Tests/coucou/GitHubActivityTests.swift -o "$TEST_DIR/github-activity-tests"
"$TEST_DIR/github-activity-tests"
