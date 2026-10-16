# Lupy — install and first-launch guide (no Terminal needed)

This guide is for a Mac with Apple silicon (your MacBook Air M1). Lupy needs **macOS 14 Sonoma or newer**.

> **About this build.** Lupy is built on **Coucou**, the little Mac companion app by Louis Raillé
> (github.com/Louis-CFM/coucou) — its window, its island, its animated Mochi, its icon and its
> sounds — extended with Lupy's assistant. Coucou's code is MIT-licensed; its character and artwork
> are included only in this private build for your own Mac (please do not share or publish the app).
> Lupy is not signed with a paid Apple Developer ID and is not notarized by Apple, so macOS will
> warn you the first time you open it. The steps below are the standard, safe way to open such an
> app. You do **not** need to turn off any macOS security setting.

## 1. Download

**Direct link** — sign in to GitHub first, with the account that can see the Lupy repository:

**{{LINK}}**

1. Click the link. Your browser downloads one file, **{{NAME}}**
   (about {{SIZE}}).
2. Double-click that file in your **Downloads** folder. You get **Lupy.app** — the app itself, and
   the only thing inside. *(Safari often unzips it for you; then Lupy is already in Downloads.)*
3. Drag **Lupy.app** into your **Applications** folder.

> **Do not use the green “Code → Download ZIP” button** on the repository page. That button gives
> you Lupy's *source code* (folders of text files), not the app.

*If the link shows “Not Found”:* you are not signed in to GitHub, or you are signed in with an
account that cannot see the (private) repository. The link works until **{{EXPIRY}}**.

*Optional check:* the file's SHA-256 fingerprint is `{{SHA}}` (built by GitHub Actions run
{{RUN}} from commit `{{COMMIT}}`).

## 2. Open Lupy the first time

macOS stops the **first** double-click because Lupy is not notarized. That is expected and safe to
get past. What you see depends on your macOS version (Apple menu → **About This Mac**):

**macOS 15 Sequoia or macOS 26 Tahoe**
1. Double-click **Lupy** in Applications. macOS says **“Lupy” Not Opened**. Click **Done**
   (not “Move to Trash”).
2. Open **System Settings → Privacy & Security** and scroll down to **Security**: “Lupy was blocked
   to protect your Mac.” Click **Open Anyway** and confirm (macOS asks once more and wants your
   password or Touch ID). The button is shown for about an hour after the blocked attempt — if it
   is missing, double-click Lupy again first.

**macOS 14 Sonoma**
1. Double-click **Lupy** in Applications. macOS says **“Lupy” cannot be opened because it is from
   an unidentified developer.** Click **OK**.
2. Control-click (or right-click) **Lupy** in Applications → **Open** → **Open**.

Lupy opens. You only do this once per downloaded version.

## 3. What you will see

The Coucou you know, with Lupy inside:

- **The Lupy window**: on the left, Lupy's pages — **Today, Needs you, Tasks, Projects, Handoffs,
  Memory, Activity, Usage & budget, Computer control, Assistant** — and below them, Coucou's own
  Flow pages (dictation history, notes, settings). Each page's top band has its colour and its
  walking Mochis. The first time, a short welcome card on Today asks the name Lupy should call you.
- **The island**: a small black bar at the top centre of the screen with **Mochi** inside (your Air
  has no notch, so it is a compact bar; on notched Macs it wraps the notch). Move the pointer over
  it to open it; click Mochi to interact; you can even drag Mochi out onto the desktop. When Lupy
  needs you, the island shows it on Coucou's card — decisions appear there with **Deny / Allow**.
- **Coucou's icon in the menu bar** (and the Dock, if enabled in General settings) with quick
  access: Lupy — Today, Stop computer control, settings, quit.
- **Sounds**: Coucou's little sounds (approval, finish, error…).
- **Voice** (optional, off by default): say **“OK Lupy”** (or “OK Coucou”) after enabling voice in
  settings; dictate into Today's box with the mic button — you always see and edit the text first.

## 4. Everyday use

1. **Tell Lupy a goal** on Today (type, or press the microphone and dictate — you always see and
   can edit the text before it is used). Pick the project, press **Plan it**.
2. **Review the plan.** Remove steps you don't want, then **Approve plan**. Nothing starts before that.
3. **Do it or delegate it.** Open a task → **Delegate to…** → Arena, Muse or Orin (ChatGPT).
   Lupy writes a clear brief. Then either paste it yourself as before, or press
   **Deliver with Lupy**: Lupy opens the agent, types the brief while you watch its cursor, and
   **asks you before clicking Send** (set where you talk to each agent once, in Lupy → Computer
   control). Lupy records the handoff honestly — *sent* only if it saw the message appear.
4. **Paste the agent's reply** into the handoff. Lupy treats it as a *claim*, not proof. If GitHub
   is connected (see the Assistant page), Lupy checks the branch, pull request and CI results itself.
5. **Accept** when Lupy shows the work as verified — or explicitly accept without verification if
   you choose (Lupy records that you did).
6. Lupy **follows up** on silence, flags missed checkpoints and deadlines, and asks you before
   anything consequential.

## 5. Computer control and the Lupy cursor

Lupy can operate apps for you while you watch — off until you turn it on:

1. **Lupy → Computer control** → turn it on. Allow **Accessibility** when macOS asks
   (System Settings → Privacy & Security → Accessibility → Lupy). This is the same permission screen
   readers use; you can remove it any time.
2. Try **“Show me”**: Lupy opens a note in TextEdit and types a line while its **orange cursor with
   Mochi** moves and clicks. Your own mouse keeps working — Lupy never moves it, and its cursor
   never blocks your clicks.
3. **Esc**, the **Stop** button on the banner, the menu bar, or pausing Lupy ends it at once. If you
   start typing, Lupy pauses so it never types over you.
4. Lupy **always asks before** sending, posting, deleting, paying, granting access or signing in —
   on the island card or in Needs you. It **never** types passwords or codes and **stops at CAPTCHA
   or two-factor screens**: those are yours.
5. **“Do something on screen”** (needs a cloud model you approved): describe a goal; Lupy picks
   each step from what is on screen, shows it, and still asks before anything consequential.

## 6. Optional: connect a cloud AI model (better plans and drafts)

Lupy → **Assistant**: add a provider key (OpenAI, Anthropic, Gemini, or any OpenAI-compatible
service). Keys go into your Mac's **Keychain**, never into Lupy's files. Approve the provider, set
a budget, and Usage shows what each call cost. Without a key, everything still works — Lupy plans
with offline rules and says so.

## 7. Optional: connect GitHub for proof of coding work

Lupy → Assistant → GitHub: paste a read-only token. Lupy checks branches, commits, pull requests and
CI results itself, so "done" from an agent becomes evidence, not a claim.

## 8. Privacy in one minute

- Your data (projects, tasks, memory, history) stays on your Mac, in `~/Library/Application Support/Lupy`.
- Keys and tokens live in the Keychain, not in files, and never in backups.
- Nothing is sent anywhere except to the cloud models you approved, within the budget you set.
- Computer control is off until you turn it on; every step is recorded in Activity with what was
  actually observed.
- Backups: Lupy → Assistant → Save a backup (a checksummed file with everything except keys).

## 9. Updating

Download the newer build (step 1), quit Lupy (menu-bar icon → Quit), and replace Lupy in
Applications. Your data stays. macOS may show the “could not verify” message again (repeat step 2)
and may ask whether Lupy may use its Keychain items — choose **Always Allow**.

## 10. Uninstalling

Quit Lupy and drag it from Applications to the Trash. Your data stays in
`~/Library/Application Support/Lupy` (delete that folder too if you want everything gone), and the
Accessibility permission can be removed in System Settings → Privacy & Security.

## 11. If something looks wrong

| Problem | What to do |
|---|---|
| The download was a zip of folders and text files, with no Lupy app | That is the source code from the green **Code → Download ZIP** button. Use the direct link in §1 instead |
| The download link shows “Not Found” | Sign in to GitHub with the account that can see the Lupy repository, then click the link again |
| No island at the top | It may be hidden: the menu-bar icon → open the island. Its settings are on the General page |
| Mochi is nowhere | Check the island (move the pointer to the top centre); Mochi may be on the desktop — drag it back to the top |
| No sounds | General settings → sound toggle and volume |
| Computer control says Accessibility is not allowed | System Settings → Privacy & Security → Accessibility → turn Lupy on, then retry |
| Dictation doesn't work | System Settings → Privacy & Security → Microphone and Speech Recognition → enable Lupy |
| “Lupy is damaged and can't be opened” | Delete it and download again; don't edit files inside the app |
| A model request fails | Lupy → Assistant → Diagnostics shows the reason in plain words (key, credit, limit, model name) |
| Lupy says it recovered from an interruption | Normal after a crash or power loss; details in Assistant → Diagnostics |
