#!/usr/bin/env bash
set -e
echo "Running IntentParser tests…"
swiftc -o /tmp/voice-intent-tests \
  Mac/Tests/coucou/VoiceTestStubs.swift \
  Mac/Tests/coucou/PillFixture.swift \
  Mac/Sources/App/Voice/VoiceIntent.swift \
  Mac/Sources/App/Voice/EntityResolver.swift \
  Mac/Sources/App/Voice/IntentParser.swift \
  Mac/Sources/App/Voice/VoiceQuery.swift \
  Mac/Tests/coucou/IntentParserTests.swift
/tmp/voice-intent-tests
