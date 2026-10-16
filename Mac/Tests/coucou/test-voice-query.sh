#!/usr/bin/env bash
set -e
echo "Running VoiceQuery tests…"
swiftc -o /tmp/voice-query-tests \
  Mac/Tests/coucou/VoiceTestStubs.swift \
  Mac/Tests/coucou/PillFixture.swift \
  Mac/Sources/App/Voice/VoiceIntent.swift \
  Mac/Sources/App/Voice/EntityResolver.swift \
  Mac/Sources/App/Voice/IntentParser.swift \
  Mac/Sources/App/Voice/VoiceQuery.swift \
  Mac/Tests/coucou/VoiceQueryTests.swift
/tmp/voice-query-tests
