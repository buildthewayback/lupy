#!/usr/bin/env bash
set -e
echo "Running VoiceActionRunner tests…"
swiftc -o /tmp/voice-runner-tests \
  Mac/Tests/coucou/VoiceTestStubs.swift \
  Mac/Tests/coucou/PillFixture.swift \
  Mac/Sources/App/Voice/VoiceIntent.swift \
  Mac/Sources/App/Voice/IntentParser.swift \
  Mac/Sources/App/Voice/VoiceQuery.swift \
  Mac/Sources/App/Voice/EntityResolver.swift \
  Mac/Sources/App/Voice/VoiceActionRunner.swift \
  Mac/Tests/coucou/VoiceActionRunnerTests.swift
/tmp/voice-runner-tests
