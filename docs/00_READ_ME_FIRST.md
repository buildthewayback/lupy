# LUPY 3 HANDOFF — READ ME FIRST (Google Drive copy)
From the first Arena session (agent had no image vision), 17 Oct 2026.

## What this folder is
Everything the next AI session needs to continue the Lupy rebuild as if it were the same
agent ("clone 99%"). The GitHub remote does NOT contain the LUPY 3 planning — those commits
were local-only — so this folder + the git bundle are the transfer.

## Read order
1. LUPY3_AGENT_MEMORY.md  <- start here (state, facts, founder profile, dead ends)
2. LUPY3_HANDOFF.md       <- the ignition key / procedure
3. LUPY3_REFERENCES.md    <- every link + the character spec (VIEW with vision!)
4. LUPY3_PLAN.md          <- all founder words, rounds 1-7
5. LUPY3_BLUEPRINT.md     <- the spec
6. LUPY3_AUDIT.md         <- the dismantle map
7. LUPY3_UI_RESEARCH.md   <- the design system
8. WORK_LOG.md            <- full work history
+ founder-ref-20261017.jpg - THE character reference (his shape: NO hands, NO legs; white
  body; tall solid-black capsule eyes, no pupils)

## Restoring the git commits
lupy3-local-commits.bundle = every local-only LUPY 3 commit (all docs + reference images).
In a clone of the lupy repo (main = 04c4693 or newer):
    git fetch /path/to/lupy3-local-commits.bundle HEAD
then merge or cherry-pick onto your working branch. If git is inconvenient: copy the .md
files into docs/ and the image into docs/concepts/, then commit - the content is identical.

## First message to the new session
"Read docs/LUPY3_HANDOFF.md first - then LUPY3_AGENT_MEMORY.md and LUPY3_REFERENCES.md.
Look at every reference with vision before designing anything. Character first, I approve,
then UI use cases, then backend."
