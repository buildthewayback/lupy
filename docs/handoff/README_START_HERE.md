# Lupy Arena Handoff — Start Here

This folder contains the full handoff for Arena AI agents to continue the Lupy project as one coordinated build campaign.

## Files and order

1. **`ARENA_MASTER_BUILD_DIRECTIVE.md`** — the controlling instruction. It contains the founder’s current authorization, scope, cost/CI rules, workflow, safety limits and expected end deliverables.
2. **`LUPY_PRODUCT_REQUIREMENTS.md`** — detailed product requirements, technical constraints, operational assurance requirements, safety, privacy, reliability, testing and acceptance expectations.
3. **`IMPLEMENTATION_SEQUENCE_AND_RELEASE_GATES.md`** — recommended internal work-package order, acceptance gates, CI budget rules, and the exact handoff/package needed at the end.
4. **`ARENA_PRIOR_ASSESSMENT_CONTEXT.md`** — facts and limitations reported in the prior Arena assessment. Re-verify anything that can vary by session, account or current repository state.

## What to do with this package

Upload the ZIP into the Arena project/session where the Coucou/Lupy work will happen, then paste the short prompt in `PASTE_TO_ARENA.txt`. If Arena can access the files directly, it should read all four Markdown documents before acting.

## Important

This package is an instruction and requirements bundle, not a source-code implementation and not a Mac installer. Arena must build the product, test it, and produce the actual source changes and installable build candidate. This ChatGPT session cannot directly dispatch a task into your Arena workspace, so use the included paste-ready handoff.
