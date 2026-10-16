#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-approval-queue.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/ApprovalQueue.swift \
    Mac/Tests/coucou/ApprovalQueueTests.swift -o "$TEST_DIR/approval-queue-tests"
"$TEST_DIR/approval-queue-tests"
