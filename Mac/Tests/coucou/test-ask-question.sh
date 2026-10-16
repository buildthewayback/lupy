#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-ask-question.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/AskQuestion.swift \
    Mac/Tests/coucou/AskQuestionTests.swift -o "$TEST_DIR/ask-question-tests"
"$TEST_DIR/ask-question-tests"
