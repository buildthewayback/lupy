# ARENA MASTER DIRECTIVE — BUILD LUPY IN ONE COORDINATED CAMPAIGN

**Product:** Lupy  
**Directive status:** Founder authorizes implementation and coordinated construction under this document.  
**Operating mode:** One continuous build campaign, internally divided into work packages, with no unnecessary founder-by-founder micro-approvals.  
**Primary goal:** Deliver a coherent, working, native macOS Lupy app that can be downloaded and installed on the founder’s MacBook Air M1, with evidence for what works, safe fallbacks for what cannot yet be connected, and a maintainable codebase that can continue growing toward the full product vision.

---

## 1. Authority, mission, and expected outcome

The founder has reviewed Arena’s feasibility assessment and is now directing Arena to continue with implementation. This supersedes the prior “assessment only / do not build” instruction from the earlier feasibility brief. Follow this directive and `LUPY_PRODUCT_REQUIREMENTS.md` together.

**Do not stop after a plan, prototype, task dashboard, or small MVP.** Build the fullest coherent product that the actual repository, tools, access and time/usage budget permit. The desired end state is a downloadable, installable Mac app, not just a repository with source code. If some capability depends on an unconnected account, external agent channel, Apple signing credential, macOS runner or missing permission, create its safe integration seam, UI/status/fallback and tests where possible, document the exact blocker, and continue the rest of the product. Do not misrepresent a placeholder or mock as a working live integration.

The founder is not a software engineer and wants the agents to make sensible low-risk design choices themselves, coordinate the work, and bring him only decisions that genuinely require his authority. Use one coordinated workstream with internally staged packages. Do not ask the founder to authorize every small implementation decision.

### Product definition

Lupy is a personal executive assistant with initiative and judgment. It manages the founder’s affairs, projects, tasks, information, tools, agent handoffs and follow-through. It plans and acts within its permissions, independently checks evidence, recovers from routine failures, preserves memory and operational state, prioritizes attention, and escalates only when user authority or human action is genuinely required.

It is **not** merely a chatbot, a chat wrapper, a to-do list, a model picker, a task dashboard, or a superficial cosmetic fork of Coucou.

## 2. Read these inputs first

Read, in this order:

1. `README_START_HERE.md`
2. This file — `ARENA_MASTER_BUILD_DIRECTIVE.md`
3. `LUPY_PRODUCT_REQUIREMENTS.md`
4. `IMPLEMENTATION_SEQUENCE_AND_RELEASE_GATES.md`
5. `ARENA_PRIOR_ASSESSMENT_CONTEXT.md`
6. The actual current Coucou repository/source and its current licence/build/test files
7. The prior full Arena assessment/report available in the session, if present

If documents disagree, this master directive governs authorization and workflow; the detailed product requirements govern desired behavior. Do not obey obsolete “do not implement” language preserved in historical materials.

## 3. How to execute: one go means one campaign, not one giant untested commit

Immediately begin by verifying the current workspace and repository access, then move into construction. Create an execution ledger and a brief, evidence-based current-state report, but do not wait for the founder to approve the plan before doing work that is already authorized.

- Work in a dedicated Lupy repository or dedicated Lupy branch. If no suitable repository is connected, work safely in the available workspace and state the exact repo connection needed; keep portable work moving while that is resolved.
- Never make changes to the upstream Coucou repository. Fork/reuse source into Lupy only as licence permits and preserve notices.
- Use small internal work packages, clear dependencies, a shared status file, test results and checkpoints. Multiple agents may work in parallel only on non-conflicting areas with explicit file ownership/interfaces.
- Before modifying the same files, have agents coordinate ownership. Integrate changes through reviewable diffs rather than overlapping edits.
- Commit coherent checkpoints to the Lupy work branch and keep a durable work log so another session can continue without reconstructing chat history.
- Keep working on independent and safe tasks if a package is blocked. Never bypass the blocker’s safety or acceptance gate merely to appear productive.
- Make reasonable reversible decisions without founder interruption. Escalate only for genuinely consequential/irreversible decisions, a legal permission the team cannot determine, spending/purchasing, external publication/communication, secrets/account-security changes, or a technical blocker that prevents safe progress.
- Don’t promise background work that the actual environment cannot run. Report visible progress and artifacts.

## 4. Architecture and product scope

Build the complete product architecture toward the full requirements from the start, then deliver it incrementally. Do not prematurely narrow Lupy to the smallest release described in the old estimate.

Expected major subsystems include:

- Coucou-derived native Mac product shell with a familiar, consistent visual language, plus Lupy-specific screens and controls.
- Executive core: goal interpretation, planning, dependencies, prioritization, bounded execution and follow-through.
- Durable, portable memory/project/task/decision state that survives application quit, crash, restart, model change and network interruption.
- Provider-neutral cloud model adapter layer; no local LLM execution and no forced model-vendor lock-in.
- Task ownership and lifecycle including handoff, acknowledgement, observed progress, evidence, verification, recovery and escalation.
- Tool/connector architecture for direct APIs first, then justified browser/computer automation and external-agent connectors where real support exists.
- Safety policy and approval gate enforced outside the model’s free-form text; scoped permissions, action idempotency and audit/event history.
- Resilient scheduling/follow-up with bounded polling, retries, concurrency and API budgets.
- Memory search/retrieval and project boundaries; global preferences may be shared only when intended.
- Backups, export/import, migration strategy, recovery, diagnostics, cost visibility and non-technical setup.
- Honest capability/status UI; “planned,” “sent,” “delivery unconfirmed,” “acknowledged,” “progress evidenced,” “submitted,” “verified,” and “accepted” must not collapse into one generic “done.”

Use the simplest maintainable architecture that satisfies the requirements. Prefer one native app/process with local structured state unless source inspection demonstrates a strong reason otherwise. Use SQLite and human-readable files if appropriate after validation; protect secrets using macOS Keychain. Avoid redundant agent frameworks, local model runtimes, heavy always-on services, unnecessary dependencies and premature cloud infrastructure.

## 5. Founder requirements that must remain central

### Target device and model strategy

- MacBook Air M1 (2021), 8 GB RAM; the founder reports around 1 GB of memory headroom.
- No local LLM inference in Lupy. Use cloud model APIs. The existing local Qwen model is not an allowed runtime dependency for this product.
- Keep the UI responsive, the background footprint small and concurrency bounded. Measure performance on the actual Mac before claiming it is smooth.
- Support changing model/provider without losing tasks, permissions, memory, or operating history.
- Explain API billing separately from ChatGPT/Arena subscriptions. Include configurable spend ceilings, per-task budgets, cancellation, bounded retries and a visible estimate/usage ledger where feasible.

### Founder’s activity portfolio

Lupy needs to manage multiple projects with a shared attention/prioritization system, including PENGLAI City, Orin/ChatGPT, Muse/Arena coordination, AI research/experiments, design/art/content, urgent income and client acquisition, files/notes, social pages/Displate, learning/browsing and personal reminders/admin. Keep project rules and data isolated where required. Rank work by urgency, consequence, income/value, strategic value, dependency, confidence, effort, risk and resource/API cost—not equally across every category.

### Executive follow-through and truthfulness

A worker’s report is a claim, not proof. Verify the actual state when possible. Record evidence sources and timestamps. Never claim that a message was dispatched if sending was not confirmed; say “delivery unconfirmed.” Never mark output complete merely because a worker said “done” or ended a session. Check acceptance criteria. Distinguish unknown from contradicted. Use bounded retries, diagnose recurring failure and change strategy instead of looping.

## 6. Coucou reuse, visual identity and legal caution

Inspect the **current** repository and exact terms before coding. The earlier assessment reported that the root code used MIT but `LICENSE-ASSETS.md` reserved some Coucou/Mochi branding, character design, icons, sounds and artwork. Re-verify that finding from source.

Reuse permitted code, view structure, interaction patterns, animation techniques and useful infrastructure aggressively. Preserve the familiar look/interaction language; do not perform an unnecessary cosmetic redesign. But do not include or redistribute reserved assets in a release if their license/permission does not allow it. If exact character/asset use is unclear, keep the UI layout and motion style while using a clearly licensed or original substitute; continue other work. Record the exact uncertainty without giving yourself legal permission by assumption.

## 7. Cost and GitHub Actions budget — hard constraint

The founder expects approximately **2,000 included GitHub Actions minutes per month**, likely on a Free plan/private repo. You must inspect the actual account/repository’s plan, current usage, billing settings, repository visibility and runner type before triggering workflows. Do not assume the displayed entitlement or remaining balance without evidence.

To minimize cost:

- Prefer tests run inside Arena’s existing sandbox and locally without consuming Actions minutes, when equivalent checks can genuinely be run there.
- Use a fast Linux standard runner for portable test suites where GitHub CI is useful.
- Do not run a full workflow on every tiny draft commit. Use focused validation during development and full regression checks at deliberate integration/release checkpoints.
- Cancel obsolete redundant workflow runs; use workflow concurrency/cancel-in-progress where appropriate.
- Minimize macOS runner time. macOS runner billing uses a much higher per-minute rate than standard Linux in GitHub’s published pricing; 2,000 included billing minutes must **not** be treated as 2,000 wall-clock macOS runner minutes. First prove available build routes. Prefer the founder’s actual Mac for final native build/runtime validation, with explicit, simple instructions, unless a limited macOS CI job is necessary and the remaining account budget permits it.
- Keep at least 30% of the verified remaining Actions budget in reserve for integration/regression/release checks. Treat 70% of the monthly allowance used as a stop-and-review threshold for all nonessential jobs. Do not enable paid overage, larger runners, paid add-ons or paid external services without explicit founder approval.
- Don’t make the repository public just to obtain free standard-runner minutes. Privacy and the founder’s code take priority over avoiding small costs. Public repository use needs explicit approval.
- Do not make CI green by weakening tests, skipping security checks, hiding failures or marking jobs `continue-on-error` without a documented justified reason.
- Record approximate Actions use after each meaningful CI batch and include weighted/macOS usage where visible. If billing details cannot be read, use conservative estimates and avoid avoidable runs.

Official reference pages to verify at execution time:
- GitHub Actions billing: https://docs.github.com/en/billing/concepts/product-billing/github-actions
- GitHub Actions limits: https://docs.github.com/en/actions/reference/limits
- GitHub-hosted runners: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Arena coding in Agent Mode: https://help.arena.ai/articles/1655691990-how-to-use-coding-in-agent-mode

## 8. Quality rules — evidence before claims

For each work package, record: objective, owner, touched areas, dependencies, acceptance criteria, tests executed, failures and fixes, result, remaining limitations, commit/branch, and artifact/log pointers.

Use these labels accurately:

- **Observed:** directly inspected state/artifact.
- **Tested:** command/test actually executed; include concise output and environment.
- **Documented:** stated in authoritative documentation, not personally executed.
- **Inferred:** reasoned but not confirmed.
- **Unknown / blocked:** evidence unavailable or access missing.

Run the closest valid test before calling anything complete, then appropriate regression tests. Add tests for new policy/state transitions, error cases, retries, migration/restart, and permissions. Inspect the actual diff; don’t rely on the agent’s description of it. A compilation success is not end-to-end acceptance. A mock or fixture is not proof that a real external integration is connected.

## 9. Security, privacy and action authorization

- Never put API keys, cookies, tokens, personal operational data or Keychain exports in GitHub, logs, test fixtures or this handoff.
- Use Keychain or another suitable OS credential store for secrets; use harmless placeholders in sample configuration.
- Keep Lupy data local by default. Clearly indicate what content goes to a cloud model/provider or third-party integration; allow the founder to inspect/configure this.
- Model output or untrusted pages/messages must never be treated as authorization to ignore safety rules or expand permissions.
- Low-risk, reversible, clearly bounded tasks may run autonomously. Spending/purchases, public publishing, sending external communications, deleting important data, account/security changes and consequential irreversible actions require explicit approval unless a narrow standing approval has been provided.
- Never bypass MFA, CAPTCHA, security checks or access controls. Stop at the gate and ask the founder when real human verification is required.
- External agents only act through real, authorized connections. If no inspectable delivery/acknowledgement exists, display delivery as unconfirmed rather than inventing status.

## 10. Product usability and installation outcome

The founder is non-technical. Do not end with instructions that require routine terminal operations or source-code editing.

The intended handoff should include:

1. Lupy source code in the persistent GitHub repo/branch with clear commit and pull-request references where available.
2. A **downloadable Mac build candidate** (`.app` inside a `.zip`, `.dmg`, or the best safe format supported) built from the known commit; never fabricate a binary if macOS compilation is unavailable.
3. SHA-256 checksum and the exact source commit/build provenance.
4. A short, plain-language install, first-launch, API setup, update, backup/export and uninstall guide.
5. A verification report showing exactly which tests ran, on what OS/hardware, what passed/failed, what was mocked, and what remains unverified.
6. A known-limitations list distinguishing working features from disabled/unconnected integrations and future work.
7. No credentials embedded in the app/package. Do not purchase an Apple developer membership, certificates, signing service, hosted service or other paid item without explicit approval.

A macOS app built without Developer ID signing/notarization may show Gatekeeper warnings or require a manual first-launch step; don’t claim a polished end-user installer until the actual packaging path is tested. Do not instruct the founder to disable macOS security globally. Prefer a safe, simple route; document signing/notarization limitations honestly.

## 11. Integration and branch policy

- Keep a durable, concise `LUPY_STATUS.md` and `WORK_LOG.md` in the Lupy work branch/repo. Update them at each meaningful checkpoint.
- Create topic branches or isolated packages for risky work. Maintain one known-good integration branch.
- Use PRs and reviewable diffs when GitHub access is available. Do not merge into a protected/default `main` branch or publish a release without explicit founder approval. You may continue building, testing and preparing a release candidate on the authorized development/integration branch without waiting for a final release decision.
- Don’t delete branches, repository history or user data as cleanup without approval.
- If GitHub connection is not configured, do not claim commits were pushed or PRs opened. Continue safely in the workspace and give exact next-step requirements.

## 12. When to ask the founder

Do not ask routine architecture/style/coding questions that can be resolved from the brief. Choose sensible defaults and record reversible assumptions. Ask only if an answer is essential to avoid significant risk or irreversible action, such as:

- permission to spend money or enable billable Actions overage;
- permission to make the repository/code/artifacts public;
- legal permission needed for reserved Coucou assets that cannot be worked around;
- an external message/publishing/deletion/account/security action;
- a choice with material irreversible consequences not answered by these documents.

If a genuine blocker occurs, report the exact evidence and keep independent safe tasks moving. Do not stop the entire campaign for an isolated missing connection or uncertain optional feature.

## 13. Final campaign completion criteria

Do not mark the campaign complete merely because all planned files exist. The final status must separate:

- **Implemented:** code exists.
- **Sandbox-validated:** relevant tests passed in the current environment.
- **Native-build-validated:** the app was built in a real macOS/Xcode environment from a known commit.
- **Installable artifact produced:** actual package exists and checksum/provenance recorded.
- **Mac runtime validated:** app launched and essential workflows were tested on the founder’s actual target Mac, if that test has been performed.
- **Founder accepted:** founder has reviewed and accepted the result.

The build campaign should aim to reach all technically accessible states and produce a real installable candidate. If the current Arena environment cannot reach the macOS steps, do as much portable work as possible, prepare the smallest reliable Mac build/packaging workflow, and clearly identify exactly what the founder must do on the Mac. Do not label untested work as finished.

**Begin now.** Verify the actual environment and repository, establish the execution ledger, inspect Coucou and its licences, then implement. Return short evidence-based checkpoints and keep going through independent work packages until the installable candidate and acceptance package are ready or a concrete blocker prevents further safe progress.
