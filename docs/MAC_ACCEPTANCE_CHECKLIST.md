# Founder acceptance checklist (on your MacBook Air M1)

A GitHub macOS runner can compile Lupy, run its self-test and launch it, but it has no notch, no
microphone and none of your accounts. These checks can only be done on your Mac. Tick each one or
write what happened — that feedback drives the next round.

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Install & first open | Follow INSTALL_GUIDE §1–2 | Lupy opens after “Open Anyway”; no “damaged” message |
| 2 | Island around the notch | Look at the top of the screen | Black island hugging the notch, Lupy's face left, counter right |
| 3 | Island interaction | Click it; move the pointer away | Opens with greeting + items; closes ~1.5 s after you leave |
| 4 | Memory footprint | Activity Monitor → Lupy → Memory | Roughly 60–150 MB at idle (Lupy runs no local AI) |
| 5 | Idle CPU | Activity Monitor → % CPU after 1 minute idle | Near 0–2 % |
| 6 | Offline plan | Today → “Renew passport then pay fee by Friday” → Plan it | Plan with 2 steps appears; nothing starts until Approve |
| 7 | Approve + do | Approve, open first task, Mark done | Second task becomes Ready |
| 8 | Restart survives | Quit Lupy (menu-bar moon → Quit) and reopen | Everything is still there |
| 9 | Dictation | Press the mic, speak, press stop | Text appears in the box for you to edit; nothing is sent automatically |
| 10 | Cloud model (optional) | Settings → provider → key → Allow → Test | “works” message; Usage shows a tiny cost |
| 11 | Model plan | Plan a goal with the model toggle on | Plan labelled with the model; Usage shows tokens and estimated cost |
| 12 | Budget stop | Set daily limit to $0.00, plan a goal | Lupy refuses to call the model and plans offline, explaining why |
| 13 | Delegation honesty | Delegate a task to Arena → paste → “I pasted it” | Status “Delivery unconfirmed”, never “delivered” |
| 14 | Claim ≠ proof | Paste an Arena reply saying “Done!” without links | Task shows “Submitted (unverified)” / “Only claims” — not Verified |
| 15 | GitHub proof (optional) | Connect GitHub, set project repo, paste a reply with a real PR link | Lupy shows PR + CI evidence; verified only if checks pass |
| 16 | Approvals | Needs you → Allow once / Deny on a demo approval | Decision recorded in Activity |
| 17 | Pause everything | Menu-bar moon → Pause everything | Island shows Lupy asleep; model calls refused |
| 18 | Backup & restore | Settings → Save a backup; then Restore it | Restored; previous data kept aside in the data folder |
| 19 | Notifications | Wait for a follow-up/approval notice outside quiet hours | At most a few notifications per hour; none during quiet hours (22:00–07:30) |
| 20 | Look & feel | Compare with Coucou | Familiar dark island/cards style, but Lupy's own character and icon |

Report anything confusing, slow or wrong — including wording.
