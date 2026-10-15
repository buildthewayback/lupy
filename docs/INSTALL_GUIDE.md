# Lupy — install and first-launch guide (no Terminal needed)

This guide is for a Mac with Apple silicon (your MacBook Air M1). Lupy needs **macOS 14 Sonoma or newer**.

> **About this build.** Lupy is not signed with a paid Apple Developer ID and is not notarized by
> Apple (that needs a paid Apple Developer membership, which has not been bought). macOS will
> therefore warn you the first time you open it. The steps below are the standard, safe way to open
> such an app. You do **not** need to turn off any macOS security setting.

## 1. Download

1. Open the Lupy repository on GitHub and click **Actions**.
2. Click the workflow **“Mac build (manual)”**, then the most recent run with a green tick.
3. At the bottom of the run page, under **Artifacts**, click **Lupy-macOS-…** to download it.
4. Open the downloaded file in Finder (double-click). You get a file named like
   `Lupy-0.1.0-<code>-macOS-arm64.zip` — double-click it too. You now have **Lupy.app**.
5. Drag **Lupy.app** into your **Applications** folder.

*Optional check:* the run's “Lupy build report” lists the file's SHA-256 fingerprint and the exact
code version it was built from.

## 2. Open Lupy the first time

1. Double-click **Lupy** in Applications.
2. macOS shows a message that it **could not verify** Lupy. Click **Done** (not “Move to Trash”).
3. Open **System Settings → Privacy & Security** and scroll down to **Security**.
   You will see “Lupy was blocked to protect your Mac.” Click **Open Anyway**, then confirm with
   your password or Touch ID.
4. Lupy opens. (On macOS 14 Sonoma you can instead Control-click Lupy → **Open** → **Open**.)

You only do this once per downloaded version.

## 3. What you will see

- A **Lupy window** with Today, Projects, Tasks, Needs you, Handoffs, Memory, Activity, Usage and Settings.
- A small black **island at the top centre of the screen** (in the menu bar — your MacBook Air M1
  has no camera notch, so it appears as a short black pill; on notched Macs it wraps around the
  notch). It shows Lupy's face and a counter of things that need you. Click it to open it; it
  closes when you move the pointer away.
- A **moon icon in the menu bar** for quick access, pausing everything, or quitting.
- A short welcome screen the first time; type the name Lupy should call you.

Lupy starts with your ten projects (PENGLAI City, Orin / ChatGPT, Muse / Arena, AI research,
Design/art & content, Urgent income & clients, Files & notes, Social media & Displate, Learning,
Personal admin). Rename, add or archive projects any time.

## 4. Everyday use

1. **Tell Lupy a goal** on Today (type, or press the microphone and dictate — you always see and
   can edit the text before it is used). Pick the project, press **Plan it**.
2. **Review the plan.** Remove steps you don't want, then **Approve plan**. Nothing starts before that.
3. **Do it or delegate it.** Open a task → **Delegate to…** → Arena, Muse or Orin (ChatGPT).
   Lupy copies a clear brief to your clipboard. Paste it into that agent, then click
   **“I pasted it”**. Lupy shows the handoff as *delivery unconfirmed* — it honestly cannot see
   inside those services.
4. **Paste the agent's reply** into the handoff. Lupy treats it as a *claim*, not proof. If GitHub
   is connected (see §6), Lupy checks the branch, pull request and CI results itself.
5. **Accept** when Lupy shows the work as verified — or explicitly accept without verification if
   you choose (Lupy records that you did).
6. Lupy **follows up** on silence, flags missed checkpoints and deadlines, and asks you before
   anything risky (spending, publishing, messaging people, deleting, security).

## 5. Optional: connect a cloud AI model (better plans and drafts)

Lupy works without one (offline plans). To add one:

1. Get an API key from a provider (for example platform.openai.com, console.anthropic.com,
   aistudio.google.com or platform.deepseek.com). Most require prepaid credit.
2. In Lupy: **Settings → Cloud model providers → Set up** on that provider.
3. Paste the key and click **Save key** — it goes into your Mac's **Keychain**, not Lupy's files.
4. Turn on **“Allow Lupy to send task context to …”**. Click **Test connection**.
5. Check **Settings → Spending limits** (defaults: $1.50/day, $10/month, $0.50/task; Lupy asks
   before any single request estimated above $0.20). Costs shown in Lupy are estimates — your
   provider's bill is final. Model names change: use **Refresh models** to see what your key offers.

## 6. Optional: connect GitHub for proof of coding work

1. On GitHub: **Settings → Developer settings → Personal access tokens → Fine-grained tokens →
   Generate new token**. Choose only the repositories Lupy should check. Permissions:
   **Contents: Read-only, Pull requests: Read-only, Checks: Read-only** (Metadata is automatic).
2. In Lupy: **Settings → GitHub evidence** → paste → **Save & test**.
3. In each coding project, enter the repository (owner/name) under **GitHub repository for evidence**.

Lupy only reads. It never pushes, merges or comments.

## 7. Privacy in one minute

- Everything Lupy knows is stored on your Mac in `~/Library/Application Support/Lupy`.
- Keys are only in the Keychain. Backups never contain keys.
- With a model allowed, Lupy sends only the context needed for that request; secrets are
  redacted, memory marked sensitive is withheld, and other projects are never included.
- Dictation uses Apple's speech recognition (on your Mac when supported for your language).

## 8. Backup, restore, move to another Mac

- **Settings → Backup → Save a backup…** creates one file. Keep it somewhere safe.
- **Restore from backup…** checks the file first, moves current data aside (never deletes it), then
  restores. Re-enter API keys afterwards (they are never in backups).
- Single projects can be exported as a readable summary or as a project file.

## 9. Updating

Download the newer build (step 1), quit Lupy (menu-bar moon → Quit Lupy), and replace Lupy in
Applications. Your data stays. macOS may show the “could not verify” message again (repeat step 2)
and may ask whether Lupy may use its Keychain items — choose **Always Allow**.

## 10. Uninstalling

1. Quit Lupy (menu-bar moon → Quit Lupy) and drag Lupy from Applications to the Trash.
2. To also remove its data: in Finder choose **Go → Go to Folder…**, type
   `~/Library/Application Support/Lupy`, and move that folder to the Trash.
3. To remove saved keys: open the **Keychain Access** app, search for “Lupy”, delete the entries.

## 11. If something looks wrong

| Problem | What to do |
|---|---|
| The island isn't visible | Menu-bar moon → turn on **Show notch island** |
| No notifications | System Settings → Notifications → Lupy → Allow |
| Dictation doesn't work | System Settings → Privacy & Security → Microphone and Speech Recognition → enable Lupy |
| “Lupy is damaged and can't be opened” | Delete it and download again; don't edit files inside the app |
| A model request fails | Settings → Diagnostics shows the reason in plain words (key, credit, limit, model name) |
| Lupy says it recovered from an interruption | Normal after a crash or power loss; details in Settings → Diagnostics |
