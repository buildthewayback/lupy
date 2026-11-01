#!/usr/bin/env python3
"""Static regression guard for Flow's provider setup and privacy text.

This checks wiring and translations, not a running SwiftUI view or a live API.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
page = (root / "Mac/Sources/App/FlowHubWords.swift").read_text()
cleanup = (root / "Mac/Sources/App/FlowCleanup.swift").read_text()
styles = page.split("struct HubStylesPage: View {", 1)[1].split("// MARK:", 1)[0]
assert ".disabled(!FlowCleanup.isAvailable && !store.cleanupEnabled)" in styles
assert "if !FlowCleanup.isAvailable {" in styles
assert "FlowCleanup.hasKey" not in styles, "Do not gate the UI on the legacy Anthropic key"
assert "router.page = .lupyAssistant" in styles
assert "LupyModel.shared.hasUsableModel" in cleanup and "return hasRoute || hasKey" in cleanup
catalog = json.loads((root / "Mac/Resources/Localizable.xcstrings").read_text())
for key in ("hub.cleanup-key", "hub.cleanup-privacy"):
    localizations = catalog["strings"][key]["localizations"]
    assert len(localizations) >= 10
    for language, entry in localizations.items():
        value = entry["stringUnit"]["value"]
        assert value.strip(), (key, language)
        # Old text incorrectly claimed all speech was local or that Anthropic
        # was the only possible provider. Check each translation was updated.
        assert "Claude" not in value, (key, language)
print("FLOW CLEANUP WIRING: PASS (static checks; live UI and providers not tested)")
