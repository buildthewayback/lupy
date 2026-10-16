# Founder acceptance checklist (on your MacBook Air M1)

A GitHub macOS runner can compile Lupy, run its self-test, launch it and even exercise computer
control — but it has no microphone, no notch and none of your accounts or agents. These checks can
only be done on your Mac. Tick each one or write what happened — that feedback drives the next round.

Lupy is now built on Coucou's own app (with your permission to use its character and artwork
privately), so several checks are about recognising the Coucou you know.

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Install & first open | Follow INSTALL_GUIDE §1–2 | Lupy opens after “Open Anyway”; no “damaged” message |
| 2 | Island at the top centre | Look at the top of the screen (the M1 Air has no notch) | Coucou's small black bar with Mochi inside, at the top centre; clicks pass through it except on Mochi; it must not cover menus you use |
| 3 | Island interaction | Click it; move the pointer away | Opens with greeting + items; closes ~1.5 s after you leave |
| 4 | Memory footprint | Activity Monitor → Lupy → Memory | Roughly 50–150 MB (Lupy runs no local AI) |
| 5 | CPU | Activity Monitor → % CPU: window frontmost; then another app in front (window still open); then island hidden (General settings) | Frontmost: noticeable while Mochi walks (that is the real animation; CI VM measured ~30–60 %, a real M1 should be lower). Background: much lower (window pauses; CI VM ~17–32 %). Island hidden: near zero |
| 6 | Offline plan | Today → “Renew passport then pay fee by Friday” → Plan it | Plan with 2 steps appears; nothing starts until Approve |
| 7 | Approve + do | Approve, open first task, Mark done | Second task becomes Ready |
| 8 | Restart survives | Quit Lupy (menu-bar moon → Quit) and reopen | Everything is still there |
| 9 | Dictation | Today → the mic button on the capture box, speak, stop | Your words appear in the box for you to edit; nothing is sent automatically |
| 10 | Cloud model (optional) | Lupy → Assistant → provider → key → Allow → Test | “works” message; Usage shows a tiny cost |
| 11 | Model plan | Plan a goal with the model toggle on | Plan labelled with the model; Usage shows tokens and estimated cost |
| 12 | Budget stop | Set daily limit to $0.00, plan a goal | Lupy refuses to call the model and plans offline, explaining why |
| 13 | Delegation honesty | Delegate a task to Arena → paste → “I pasted it” | Status “Delivery unconfirmed”, never “delivered” |
| 14 | Claim ≠ proof | Paste an Arena reply saying “Done!” without links | Task shows “Submitted (unverified)” / “Only claims” — not Verified |
| 15 | GitHub proof (optional) | Connect GitHub, set project repo, paste a reply with a real PR link | Lupy shows PR + CI evidence; verified only if checks pass |
| 16 | Approvals | Needs you → Allow once / Deny on a demo approval | Decision recorded in Activity |
| 17 | Pause everything | Lupy → Assistant → Pause everything | Mochi sleeps; model calls and computer control refused |
| 18 | Backup & restore | Lupy → Assistant → Save a backup; then Restore it | Restored; previous data kept aside in the data folder |
| 19 | Notifications | Wait for a follow-up/approval notice outside quiet hours | At most a few notifications per hour; none during quiet hours (22:00–07:30) |
| 20 | Look & feel — Coucou restored | Compare with the Coucou you know | Coucou's icon in the Dock/Applications and the menu bar, Mochi animated (blinks, looks around, reacts to the pointer), the same dark cards and buttons, Coucou's sounds |
| 21 | Sounds | Let Mochi finish something (or approve something) | Coucou's little sounds play (toggle: General settings) |
| 22 | Computer control permission | Lupy → Computer control → turn it on → Allow in System Settings… (Accessibility) | macOS shows its permission page; after allowing, the page says “Allowed” |
| 23 | Watch the cursor | Lupy → Computer control → “Show me” | An orange Lupy cursor with Mochi moves to TextEdit, a line is typed while you watch; your own mouse still works; Esc or Stop ends it |
| 24 | Deliver a handoff | Handoffs → a handoff to an agent you use → “Deliver with Lupy” (set where you talk to that agent first) | Lupy opens it, types the brief, and asks before clicking Send; afterwards the handoff says Sent (seen on screen) or Delivery unconfirmed — honestly |
| 25 | Esc and typing safety | During any computer control: press Esc; another time, just start typing | Everything still queued is cancelled; typing pauses Lupy so it never types over you |

Report anything confusing, slow or wrong — including wording.
