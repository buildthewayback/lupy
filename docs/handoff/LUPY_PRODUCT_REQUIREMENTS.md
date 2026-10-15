# LUPY — Product Requirements and Acceptance Reference

**Status:** Implementation requirements for the authorized Lupy build campaign.  
**Authority:** `ARENA_MASTER_BUILD_DIRECTIVE.md` is the governing execution instruction.  
**Purpose:** This document preserves the detailed product, safety, testing, cost, risk, and acceptance requirements from the previous feasibility brief.

## Precedence and how to use this file

1. Read `README_START_HERE.md` first, then `ARENA_MASTER_BUILD_DIRECTIVE.md`.
2. This file is the detailed requirements reference. Treat its product requirements as active.
3. The earlier feasibility-only instruction that said “do not build” has been superseded by the founder’s newer explicit authorization in `ARENA_MASTER_BUILD_DIRECTIVE.md`. Do **not** follow obsolete planning-only language if any remains in historical context.
4. Do not use this as an excuse to stop after a plan or prototype. Produce working code, tests, integration evidence, and a downloadable native Mac build candidate to the extent the available tools genuinely permit.
5. If a requirement depends on a missing credential, platform, account permission, legal right, or external service, implement the safe architecture and honest status/fallback where possible; document the exact blocked verification. Continue independent work.

---

## 1. The product we are trying to build

### 1.1 Product definition

**Lupy is a personal executive assistant with initiative and judgment.** It helps manage the founder's projects, work, information, tools, digital activities and follow-through. It should behave more like a capable executive assistant / chief of staff than a chatbot that waits for one instruction at a time.

Lupy should:

- Understand the founder's priorities, projects, rules, preferences and constraints.
- Turn outcomes into plans, tasks, dependencies, checkpoints and acceptance criteria.
- Do the work it is authorized and technically able to do, using direct integrations, computer/browser control, or delegated agents as appropriate.
- Coordinate agents without forcing the founder to relay every message or supervise every step.
- Check whether a handoff really happened and whether work is actually progressing.
- Verify results independently rather than trusting a worker's confident report.
- Recover intelligently from routine failures, choose a different route when a route is not working, and learn from repeat failures.
- Keep a durable record of tasks and decisions after chats end, the app closes, the computer restarts, or a model/provider changes.
- Protect the founder's attention by bringing him in when his authority, judgment, private knowledge, or human verification is genuinely needed.
- Be candid about uncertainty and capability. It must never claim success without adequate evidence.

Lupy is **not** merely a chat wrapper, prompt collection, to-do list, coding agent, model selector, or thin patch to Coucou. The goal is a coherent new product with a complete operational backend and the necessary user interface, built by reusing suitable existing components instead of reinventing working parts.

### 1.2 Build a new product by reusing the right parts

Coucou is the proposed existing foundation for the interface and selected useful capabilities. Lupy should reuse or adapt suitable parts of Coucou, while adding or replacing whatever is needed to deliver Lupy's product requirements. Do not assume that every Coucou feature should be retained, and do not assume the existing frontend already provides capabilities it does not actually have.

The intended relationship is:

- **Coucou's current visual style, character, animations and familiar interaction pattern:** preserve where practical.
- **Lupy's product identity and behavior:** new and purpose-built for this founder.
- **Frontend:** reuse Coucou components where they are fit for purpose, and add the missing Lupy screens, controls, status displays, permissions, history and workflows in the same visual language.
- **Backend/core:** design and build the missing operational system: planning, durable state, memory retrieval, tool use, integrations, task supervision, verification, recovery, scheduling, permissions and provider-independent orchestration.
- **Integration:** make the frontend and backend work together as one cohesive product. Avoid two disconnected apps, duplicate control centers, or multiple competing agent runtimes.

First inspect the actual upstream Coucou repository, its license, current version/commit, architecture, supported macOS versions, dependencies, build process, and code quality. Confirm the correct repository and whether its current license permits the intended private use and any planned modifications/distribution. Do not rely on a README alone; verify important facts against the source.

### 1.3 Who it is for

- One individual founder, initially.
- The founder is not a software engineer and should not need to operate terminals, manage databases, troubleshoot routine failures, or coordinate every agent manually during ordinary use.
- The first supported target is the founder's own MacBook Air. The core data and architecture should remain portable enough to migrate to a future computer without losing history or being locked to one model provider.
- This is a private personal assistant, not initially a multi-tenant SaaS product. Avoid enterprise-scale complexity unless a concrete requirement justifies it.

---

---

## 2. The founder's actual environment and constraints

Treat these as fixed design requirements unless inspection later reveals a specific incompatibility that must be reported.

### 2.1 Target computer

- MacBook Air M1, 2021.
- 8 GB total RAM.
- Usually only about **1 GB of extra RAM headroom is available**. Therefore the installed Lupy app and its background processes must be lightweight and avoid unnecessary persistent services.
- The founder wants Lupy to feel smooth, responsive and dependable—not just technically launch.
- No local LLM inference will be run by Lupy. **Do not design the v1 around a local model, local Ollama server, large local model download, GPU inference, or local model hosting.** The founder will connect cloud model APIs.
- The existing local Qwen model is not a required runtime dependency and should not be invoked by Lupy in this plan.

### 2.2 Model access

Cloud APIs will provide model reasoning. Investigate a provider-neutral interface that can support the founder's selected API provider(s), potentially including OpenAI, Anthropic/Claude, DeepSeek and other compatible providers if justified. Do not hardwire the whole application to one vendor unnecessarily.

The report must explain:

- Which API providers are realistically supported, and by what code or integration.
- Which API keys are required, where they will be stored, and how a non-technical user can add/change them.
- Whether model switching can preserve the same task state, memory, permissions and history.
- How model capability is selected by task type without creating expensive uncontrolled loops.
- What information is sent to each provider, and how the founder can see/control it.
- How rate limits, provider failures, token limits, unavailable models and API billing are handled.

**Important:** A ChatGPT subscription, an Arena free plan, or an agent's access to a model must not be assumed to include API credits for Lupy. Report likely separate API costs and any uncertainty.

### 2.3 Development environment

Arena is the preferred first place to conduct discovery, plan the work, and—after separate authorization—perform as much coding, testing, bug fixing and integration work as its sandbox genuinely supports. The project should use GitHub as its persistent source of truth.

The founder prefers to avoid buying paid coding-agent subscriptions unless a real blocker proves that one is needed. Do not assume Arena free access is unlimited. Determine what the current workspace/account visibly supports and identify quotas or limitations that can be verified. Do not invent exact quotas if you cannot inspect them.

The founder does not want to install development infrastructure on the Mac while we are still planning. The first implementation work should be performed away from the personal Mac wherever feasible. Installation and device-specific acceptance testing are a later, controlled stage.

---

---

## 3. The founder's work and what Lupy must help manage

Lupy should manage a portfolio of activities with different values, deadlines, dependencies and urgency. It must not allocate equal time to everything just because all items are listed.

Known recurring activity areas include:

1. PENGLAI City development—a large, long-term product.
2. ChatGPT / Orin conversations and decisions.
3. Muse and Arena agent coordination.
4. Researching and experimenting with AI tools.
5. Digital art, visual design and content creation.
6. Client acquisition and income opportunities, which are currently urgent.
7. Files, notes and project documentation.
8. Facebook pages and Displate work.
9. Learning, watching videos and general web browsing.
10. Personal tasks, reminders and everyday admin.

The founder may add or remove projects. Each project needs isolated requirements, state, rules, documents, current status, decisions, next actions and relevant history. Some carefully selected knowledge may be shared across projects, but project boundaries must not be lost.

The system should help balance:

- Urgency, deadlines and consequences of missing them.
- Potential income/value and immediate financial needs.
- Strategic importance and long-term benefits.
- Dependencies and whether other work is blocked by a task.
- Risk, confidence and expected effort.
- Resource use, API cost and computer workload.
- The founder's energy, attention and chosen schedule, if he supplies that information.

It should identify stalled work and neglect, but avoid noisy notifications. It should be capable of recommending trade-offs and explaining important priority changes briefly.

---

---

## 4. Required capability: executive ownership and follow-through

This is a core product requirement, not an optional enhancement.

A conventional assistant may accept a task, try once, report an error, and stop. Lupy must instead own the authorized outcome until the outcome is accepted, cancelled by an authorized person, or blocked by a genuine limitation that is clearly documented and raised at the appropriate time.

For example, when work is delegated, Lupy should not just send the request. It should track it, check whether the recipient received and acknowledged it, confirm that work began, inspect evidence of progress, validate the delivered result and coordinate the remaining steps.

Expected lifecycle states should include appropriate equivalents of:

- Planned / queued.
- Ready / in progress.
- Dispatched to a worker or tool.
- Delivery unconfirmed.
- Acknowledged.
- Progress evidenced.
- Blocked / waiting on a dependency or approval.
- Deliverable submitted.
- Verification in progress.
- Failed / recovery underway.
- Verified / accepted.
- Completed, cancelled, or escalated to founder.

Define which states are necessary for each task type rather than forcing every tiny task through an oversized workflow. A completion claim must be connected to the task's acceptance criteria and the evidence obtained.

Lupy should:

- Keep a current and durable view of work that is active, queued, blocked, failed, completed or waiting on a person.
- Follow up at sensible checkpoints when no progress is detected.
- Distinguish between “worker says it is working,” “message delivery confirmed,” “progress observed,” “output received,” “tests passed,” and “outcome independently verified.”
- Avoid duplicate or conflicting actions after retries, reconnects or restarts.
- Continue unrelated, safe work when another task is blocked. It must not bypass rules or dependencies simply to look productive.
- Escalate only the unresolved decisions or actions that truly need the founder.

---

---

## 5. Critical capability: independent execution assurance

The founder has repeatedly seen delegated agents report activity or completion that was not supported by what actually happened. Examples have included:

- A worker saying a task was “with Arena” without reliable evidence that the instruction was actually dispatched and acknowledged.
- Reports of a session or browser state that did not match observable reality.
- A worker claiming a cleanup/action had happened when it had not been verified.
- Agents discussing a task amongst themselves but never completing the actual handoff or deliverable.
- Forgotten instructions, missing deliverables, rules being violated, and the founder having to manually inspect the work.

Lupy is being built in part to remove this constant manual supervision.

### 5.1 Evidence rules

- A worker's words are a **claim**, not proof.
- Track the source and time of evidence. Prefer independent artifacts: repository commits, pull requests, CI results, test output, changed files, API responses, delivery acknowledgements, screenshots or observed application state, depending on the task.
- Do not imply that evidence exists when the integration cannot expose it. Mark the result “unverified” or “delivery unconfirmed.”
- Distinguish “not observed” from “proved not to have happened.” Avoid accusing a worker of lying when evidence is only incomplete or ambiguous.
- Completion should be based on defined acceptance conditions, not on the worker's final message or session ending.
- Preserve a compact audit trail showing what was requested, who/what acted, which rules applied, what evidence was examined, what checks passed/failed, and why the final status was chosen.

### 5.2 Handoff verification

For a delegated task, Lupy should make it possible to answer:

1. Was the request actually sent through the relevant channel?
2. Do we have delivery evidence or is delivery still unconfirmed?
3. Did the receiving agent acknowledge it?
4. Is there evidence the receiver began work?
5. Is the receiver following the correct project instructions and scope?
6. Is there a deliverable or inspectable progress artifact?
7. Does that deliverable meet the acceptance criteria?
8. Has it been safely integrated, if integration was required and authorized?

If a channel cannot be monitored, Lupy must say so and select a practical fallback rather than fabricate status. Assess which of the founder's current channels/tools can actually be connected to Lupy, and what permissions or technical work are required.

### 5.3 Computer-action verification

If Lupy changes browser/app state, closes tabs, edits files, updates a task or performs another computer action, it should verify the intended result using the best available evidence. It must not close unrelated personal browser sessions or cross session/profile boundaries without authorization.

Direct API results, application state and browser DOM are generally preferable where available; screenshot/visual inspection may be needed for GUI-only workflows. Use the least fragile supported method and explain any known blind spots.

---

---

## 6. Critical capability: worker reliability and learning

Lupy should learn which workflows and delegated workers are reliable based on their historical results, while remaining fair and evidence-based.

Possible evidence dimensions:

- Accuracy of status claims.
- Actual instruction adherence.
- Deliverable quality and test outcomes.
- Evidence quality.
- Reliability of handoffs.
- Timeliness and missed checkpoints.
- Recovery behavior after an error.
- Reliability for a particular kind of task.
- Repeated patterns across tasks, without overreacting to one ambiguous incident.

Trust should be **task-specific and adjustable**, not a permanent binary label. A worker may be good at one task type and poor at another. Repeated unsupported claims should trigger more independent checking or less autonomy for the relevant workflow. Verified improvement may gradually restore autonomy.

The founder should be able to inspect why a trust/reliability assessment changed and correct a mistaken assessment. Trust learning must never override safety controls, access permissions, or the need for approval on consequential actions.

Lupy should learn from its own errors and founder corrections. If a workflow fails repeatedly, improve or replace the workflow—not merely tell the same agent to remember the same instruction again. Include safeguards against incorrect attribution, stale evidence, biased scoring and overconfident conclusions.

Report a practical way to implement this without building an unnecessarily complicated or opaque “AI trust score.” A clear rule-based baseline may be better than a complex scoring model at first.

---

---

## 7. Memory, durable state and portability

Lupy must not depend on the live chat transcript as its only memory or on one model vendor's private memory. It must recover its operational state across app closure, restart, model switching, network interruption and agent-session changes.

### 7.1 Memory categories

At minimum, assess how to store and retrieve:

- Founder preferences and standing instructions.
- Global rules and safety boundaries.
- Separate project goals, requirements and rules.
- Decisions, rationale and decision status.
- Current project/task state and next steps.
- Task dependencies, deadlines, priorities and acceptance criteria.
- Delegation recipients, messages/handoffs, expected outputs and checkpoints.
- Evidence references, tests, failures, recoveries and lessons.
- Tool/provider configuration and non-secret operational settings.
- Permissions, authorizations and expiry/scope of standing approvals.
- A useful history of actions and changes.

### 7.2 Storage requirements

Recommend a simple, dependable design. A plausible approach is human-readable local project/memory files plus a local structured database for operational state, but validate the best option rather than blindly adopting this example.

The report must cover:

- What is stored as readable files versus structured state.
- Which data remains local and which portions are sent to cloud providers or external tools.
- Database integrity, migrations, backups and restore tests.
- Export/import so the founder can move to another device.
- How projects can be backed up independently and restored without losing unrelated data.
- How stale or contradictory memory is reconciled.
- How sensitive items are excluded from GitHub.
- How to avoid duplicate tasks or duplicate external actions after recovery.

The founder controls the data. The core state format should be documented and as portable as practical. GitHub is suitable for source code, tests, implementation docs and approved work packages—not API secrets or unrestricted private memory/credentials.

---

---

## 8. Planning, priorities, proactive behavior and notifications

Lupy should support planning and execution together. It should not produce an elaborate dashboard just to appear capable.

Required behavior to assess:

- Convert goals or incoming requests into clear next actions.
- Detect dependencies, conflicts, missing acceptance criteria and unrealistic commitments.
- Keep deadlines and checkpoints and surface overdue/stalled work.
- Periodically perform lightweight reviews and event-driven checks where practical.
- Detect meaningful changes, risks, opportunities and neglected priorities.
- Propose or execute safe next steps under the founder's chosen autonomy settings.
- Explain important priority trade-offs briefly.
- Avoid endless polling, excessive notifications, wasteful API calls and repetitive status messages.
- Pause, resume, cancel or reprioritize tasks cleanly.
- Keep the founder's attention on meaningful results and decisions rather than agent chatter.

Assess what can run as a lightweight in-app scheduler versus what needs a background process or external service. Any always-running component needs a clear reason, a resource budget, and restart behavior.

---

---

## 9. Tool and computer execution

Lupy must eventually be able to take useful actions, not only give instructions. The technical design should select the most reliable route per operation, with fallbacks where justified:

1. Direct API or supported application integration.
2. Browser automation when an API is unavailable or insufficient.
3. Visual computer control when the task genuinely requires a graphical interface.
4. Delegation to a suitable connected agent/worker when that is the better route.
5. A bounded manual step only when access, human judgment or a protected verification step makes it necessary.

The report must compare realistic tools/frameworks for this use case and recommend **one primary execution strategy**, not install or integrate several overlapping agent frameworks without justification. Open Interpreter Workstation, browser-control tools, native macOS automation and other established options may be investigated as candidates, but no candidate should be selected solely because it sounds promising. Check maintenance, security model, licensing, Mac compatibility, memory/CPU overhead, browser support, headless/GUI requirements, recovery behavior and ability to run under Lupy's permission model.

Required concerns:

- How the tool can access only approved files, windows, apps, profiles and accounts.
- How it reports actionable evidence back to Lupy.
- How browser sessions are isolated; how login state is handled safely.
- Whether an action is repeatable/idempotent and how duplicate actions are prevented.
- What happens with network drops, expired sessions, changed page layouts, timeouts, pop-ups, rate limits and blocked access.
- How CAPTCHA, MFA and human-verification steps are handled safely. Lupy must not bypass them; it should prepare the work and request the founder when required.
- How to test computer actions with mock/test accounts and without affecting real production data.
- Whether the technology can actually be automated and tested from the Arena sandbox and which things require later verification on macOS.

For example, if asked to close a tab, Lupy must know which authorized browser/session is in scope, close only the intended tab, and check the result. It must not claim it did so merely because it sent a command.

---

---

## 10. Agent and service coordination

Lupy may coordinate tools and agents such as Arena, Muse, Orin/ChatGPT, coding assistants and other future workers. These must be integrations with explicit contracts, not assumptions that another agent is always available or truthful.

Assess which channels and integrations are actually feasible. For each candidate, specify:

- How Lupy sends instructions and receives replies/results.
- Whether status/progress can be observed independently.
- Whether it supports attachments, links, files, commits, PRs or test evidence.
- Authentication/security requirements and API availability.
- Polling, latency, limits and likely cost.
- Failure states and what Lupy does when the recipient cannot be reached.
- Whether a human must perform initial authorization/login.

Lupy should use the fewest workers that reliably solve a problem, parallelize independent work, avoid conflicting edits, and obey task dependencies. It remains accountable for the overall outcome even when work is delegated.

Project-specific rules must survive delegation. For PENGLAI, for example, the founder's repo workflow and no-master-merge-without-founder-authorization rule must be respected. Never assume that a worker can access a repo, chat, browser or agent simply because the founder uses it elsewhere; verify the actual connection path.

---

---

## 11. Autonomy, approvals and safety

Lupy needs a clear permissions model that balances initiative with user control.

Assess a small, understandable autonomy model along these lines:

- **Observe / advise:** read permitted information and recommend actions.
- **Prepare / ask:** prepare a change or external action, then request approval before execution.
- **Bounded autonomy:** perform named, low-risk, reversible actions within an explicit scope and time/usage limit.

Routine, low-risk, reversible tasks may be automatic within a clearly defined authorization. Actions such as sending external communications, publishing content, spending money, deleting important data, changing account security, granting access, merging to protected branches, deploying, or making other consequential/irreversible changes require the relevant approval unless the founder has explicitly given a clear, limited, revocable standing authorization.

The implementation should make permission boundaries enforceable in code where possible, not rely exclusively on a prompt. It must explain the action, target, material consequence and evidence before asking the founder for approval. It should record the authorization and ensure it does not silently expand its scope.

Also assess prompt injection and malicious instructions in web pages, files, emails, messages, repository issues and agent outputs. Retrieved content is untrusted data and must not be allowed to rewrite Lupy's rules or permission boundaries. Include data-loss prevention, credential protection, safe logging and a stop/pause control.

Do not bypass MFA, CAPTCHA, access controls or other legitimate security barriers. If a task requires human authentication or review, pause at that boundary and ask the founder.

---

---

## 12. Model routing, API use and cost control

The founder explicitly does not want to run local LLMs. Reasoning will use configured cloud model APIs. Lupy itself should remain usable even if a provider has an outage, provided a safe fallback is configured.

Assess a simple model/provider adapter layer with:

- Configurable providers and models.
- A clear default model and deliberate fallback rules.
- Model selection based on task needs, latency, availability and estimated cost.
- Rate-limit and transient-failure handling with bounded retries/backoff.
- Explicit maximum retry/step/token/budget ceilings to prevent loops.
- Request/time/cost metrics where the provider exposes them.
- Per-task and per-day/month usage limits, alerts and a global pause switch.
- A way to disable a provider without losing persistent state.
- No silent switch to a provider the founder has not enabled or approved.
- Clear notice about what context/data is sent to a provider.
- Redaction/minimization of secrets and irrelevant private data before sending requests.

Give rough monthly API cost ranges for realistic light, normal and heavy use, with assumptions, representative model pricing sources and a warning that actual spending depends on volume and model selection. Do not invent a precise bill without a usage model. Include the cost of any non-API external services that the proposed architecture requires.

---

---

## 13. User experience and frontend requirements

### 13.1 Preserve Coucou's style

The founder likes Coucou's existing interface and character. Keep its current visual appearance, character, animations and overall feel wherever possible. Cosmetic redesign is not a project goal. Do not spend the budget/time remaking a front end that already works.

However, do not sacrifice critical functionality to preserve a screen that cannot support it. Add the minimum extra UI necessary, using the same design language and interaction conventions. If significant Coucou code is incompatible or unsuitable, show evidence and explain options before proposing a replacement.

### 13.2 Simple and useful interface

The user is non-technical. The interface should make the key operational facts easy to see without turning into a complex administration console.

Investigate a compact way to show:

- What Lupy is doing now and why.
- Important active tasks, queued work, blocked work and items requiring the founder.
- Whether delegated work is merely reported, independently evidenced or verified.
- Recent meaningful results and next actions.
- Approval requests and the exact action being approved.
- API provider/model status, approximate usage/cost and pause controls.
- Current autonomy/privacy settings and any exceptional access being used.
- A searchable task/history/activity record when the founder needs to inspect it.

Avoid noisy animations, excessive popups, a giant dashboard, many configuration screens and technical jargon. Do not interrupt for trivial decisions that Lupy is authorized to make.

### 13.3 Voice and text input

Voice/dictation is desirable because the founder finds speaking easier than typing accurately. First inspect whether Coucou's existing voice features can be reused. Where speech transcription is used, show the transcription and allow review/correction before sending during the first version. Correct spelling/grammar while preserving the intended meaning; do not silently change the instruction's meaning. Report whether speech processing is local or cloud-based, what data is sent, language support and costs.

---

---

## 14. Reliability, recovery and service health

The system should be designed for ordinary real-world failures, not only ideal demonstrations.

Assess behavior for:

- App crash or forced quit.
- Mac sleep, reboot or app restart.
- Internet/API outage, slow responses and rate limits.
- Expired/revoked API credentials.
- A model producing invalid or contradictory output.
- A tool/agent timing out or returning partial output.
- A task being submitted twice, concurrent changes or stale state.
- A failed database write or interrupted migration.
- A worker claiming success when artifacts are missing.
- A browser session being logged out or navigating to the wrong account.
- Repeated retries that do not solve the underlying problem.
- An integration being unavailable or permanently unsupported.

Prefer bounded retries, checkpoints, resumable jobs, idempotency keys where appropriate, safe cancellation, explicit error categories and recovery from the last durable checkpoint. Repeatedly retrying the same failing method is not acceptable. Lupy should diagnose, change strategy or surface the true blocker.

Define when work may safely continue automatically and when it must pause. A recovery mechanism must not duplicate a consequential external action or override the founder's approvals.

---

---

## 15. Security, privacy and data ownership

The founder's information and credentials are private. The report must treat privacy/security as architecture, not an afterthought.

Requirements to plan for:

- Store provider API keys and other secrets in macOS Keychain or a similarly appropriate secure credential store, not plaintext project files, source code, logs or GitHub.
- Provide a simple way to add, replace, revoke and verify a key without exposing it.
- Keep private operational memory and account data out of public repositories. Do not commit private memory to GitHub by default.
- Separate configuration, credentials, operational state, logs and source code.
- Explain which data remains on the Mac and which is sent to a model provider, tool, agent or integration.
- Minimize data sent externally and avoid placing secrets in prompts unless absolutely required and appropriately protected.
- Encrypt backups that contain sensitive personal state, and test restoring them.
- Limit file/app/browser access to the minimum needed for an approved task.
- Keep auditable records of high-impact actions and permission changes without logging secrets.
- Provide pause/disable controls and a safe shutdown path.
- Protect against prompt injection from websites, documents and other untrusted sources.
- Consider dependency supply-chain risk, supported update path, signed/notarized app distribution where applicable, and secure defaults.
- Clarify what is and is not protected by the selected cloud API provider's data policy, based on current official documentation.

Because the model runs through an API, the founder must understand that content sent to a cloud provider leaves the Mac. Do not describe API mode as “local-only” or claim that all data never leaves the device.

---

---

## 16. Performance requirements for the 8 GB Mac

Performance must be treated as a feature. The app should not make the machine unusable during ordinary work.

Prepare a concrete resource budget for the installed app and any helper/background process. The report must specify:

- Expected baseline and active RAM use for each component, with source or measurement method.
- Which services run continuously and why.
- CPU and disk activity during idle, normal activity and busy periods.
- Whether any tool requires Docker, virtual machines, containers, browsers, local databases or heavyweight runtimes; explain the actual resident overhead.
- What can run on demand rather than continuously.
- Limits on concurrent workflows and browser sessions.
- How API/network wait time is managed without consuming local resources.
- How logging and memory growth are bounded.
- What happens under memory pressure and how the app recovers.

The founder estimates only about 1 GB of extra RAM is normally available, so do not propose a heavy multi-agent stack running permanently. Cloud reasoning reduces local inference load but does not eliminate the local footprint of browser automation, Electron/WebViews, databases, services, monitoring or helper runtimes.

Where actual measurements cannot be taken in Arena, mark them as unverified and include the later Mac acceptance test needed to measure them. Do not invent benchmark numbers.

---

---

## 17. Testing standard: prove it works, not just that it compiles

The goal is a dependable first product, with bugs found and fixed systematically. In the later build phase, Arena should test within the sandbox as far as possible, fix failures, rerun the relevant tests, run regression tests, and keep evidence. The founder should not have to be the primary tester.

The feasibility report must state which of the following Arena can perform now, which it can perform after code exists, and which cannot be completed without access to a real Mac or real authorized external accounts.

### 17.1 Test categories

1. **Static checks:** linting, formatting, type checks, dependency and secret scans where appropriate.
2. **Unit tests:** task state transitions, prioritization rules, permissions, cost ceilings, retry rules, memory/state logic and trust/evidence calculations.
3. **Integration tests:** database, model-provider adapters, tool/agent adapters, authentication handling and app/backend communication.
4. **Contract tests:** validate provider/tool response shapes, errors and timeout behavior.
5. **End-to-end tests:** realistic task flows through the interface and backend, using mock or sandbox accounts.
6. **Recovery tests:** quit/restart, interrupted task, network loss, expired key, partial result, duplicate submission, interrupted persistence and resumable work.
7. **Adversarial/safety tests:** prompt injection from untrusted content, unauthorized action attempts, missing approval, secret leakage, unsafe file access and untrusted agent claims.
8. **Reliability tests:** repeated runs, regression suite, flaky tests, stale evidence and failed handoffs.
9. **Performance tests:** startup, idle behavior, responsiveness, memory use, concurrency limits, long-running activity and log/state growth.
10. **Packaging/update tests:** clean install, launch, update, rollback, backup, restore and removal where applicable.
11. **Real-device acceptance:** native macOS build and permissions, Keychain, sleep/reboot recovery, voice features if included, real RAM/CPU usage and UI interactions on the target Mac.

### 17.2 Required testing behavior during implementation

Once separately authorized to build:

- Add meaningful tests with each feature rather than postponing all tests until the end.
- Run the appropriate tests after every change and the complete regression suite at relevant integration points.
- Fix bugs and rerun tests; do not merely document avoidable bugs as known issues.
- Do not weaken, delete or skip tests just to get a green result.
- Keep test output, commit/PR references and known limitations attached to the relevant work package.
- Use mocks or fixtures for expensive/unsafe real integrations. Clearly distinguish mocks from real integration tests.
- Never run destructive tests against the founder's real accounts or data.
- If CI minutes or another quota is exhausted, continue safe independent work, local/sandbox tests and review where possible; do not bypass required acceptance rules. Report what cannot be proven until CI is available.
- Keep `main` protected and do not merge without the founder's explicit authorization.

### 17.3 Product acceptance expectations

The later release should not be called “done” solely because the app starts or a demo succeeds. Define measurable acceptance criteria for every major feature and the complete product. Any critical security, data-loss, duplicate-action, permission-bypass or false-completion defect must block release until fixed or explicitly accepted by the founder with full context.

---

---

## 18. Source-code and dependency audit required before recommending architecture

Inspect the real Coucou source, not just product descriptions. Confirm the exact repository URL, commit or release tag, license and build instructions. Report results for:

- Language/framework and application entry points.
- UI composition and ability to preserve the existing character, animations and design.
- Existing model/API abstraction and provider support.
- Existing voice/transcription/dictation implementation.
- Existing agent/session hooks and which agent types they actually support.
- Existing GitHub/Vercel/other integrations and whether they are functional, partial or only UI/documented.
- File access, memory/state persistence, task handling and background work already present.
- Existing browser/computer automation, if any, verified against code.
- Credential storage, logging and privacy-related code.
- Build, signing, permissions, supported macOS versions, dependencies, test coverage and release process.
- Known open issues, stale dependencies, architectural limitations, maintenance activity and license obligations.

For each capability, label it as one of:

- **Reuse as-is:** works and satisfies the requirement.
- **Reuse with changes:** useful but requires modification.
- **Replace:** existing implementation is inadequate or risky.
- **New build required:** no suitable existing implementation found.
- **Unverified:** source/evidence insufficient.

Do not rewrite something that works merely for stylistic preference. Conversely, do not preserve a poor or insecure implementation just because it is already there. Give evidence and an impact estimate for each meaningful decision.

Also check relevant maintained third-party projects or libraries where they could materially reduce work. Compare candidates only against specific requirements: current maintenance, license, Mac compatibility, security, API/provider flexibility, resource overhead, testability and ability to provide evidence. Recommend the smallest suitable set. Do not accumulate multiple frameworks that each duplicate planning, memory, browser control, scheduling or agent orchestration.

---

---

## 21. Cost, external dependencies and free-first strategy

Provide an itemized cost and dependency forecast:

- Arena plan/usage assumptions and visible limitations.
- GitHub features required and any potential costs.
- Model API usage estimates under light, normal and heavy use.
- Any database, hosted service, storage, browser-control or monitoring service costs.
- Any required paid license or commercial dependency.
- Costs that are optional versus unavoidable.
- An approach that works with no new paid coding-agent subscription initially, where feasible.

The goal is not “free at any cost.” The goal is the best reliable product at the lowest sensible cost, avoiding paid services where existing/free components are sufficient and avoiding false economies that create a fragile product.

Never recommend embedding production credentials, unrestricted access tokens or private operational data in GitHub to save effort. Do not use a fake “free” estimate that ignores API billing or service limits.

---

---

## 22. Major risk and failure analysis

List realistic project and runtime risks, each with likelihood, impact, evidence/confidence and mitigation. At minimum consider:

- Coucou's native macOS build cannot be built or fully tested in Arena's sandbox.
- Coucou does not contain the presumed capability or integration.
- Browser/computer control is unavailable, brittle or too resource-heavy.
- Agent channels do not provide delivery acknowledgements or inspectable progress.
- Arena free-tier limits interrupt coherent progress.
- Model API costs or rate limits exceed expectations.
- The app uses more RAM than the available headroom permits.
- State/memory corruption or repeated actions after a crash.
- Agent claims cannot be independently verified through the available interfaces.
- Prompt injection or untrusted data tries to authorize an action.
- UI changes break existing Coucou behavior.
- Dependency/license/security issues make reuse inappropriate.
- The project grows into an unnecessarily complex multi-agent framework.
- Sandbox tests pass while real Mac or live integrations fail.

For each risk, identify preventive design, detection method, recovery path, and whether the founder must decide anything. State which features are technically feasible, feasible with important limitations, not feasible in this environment, or not yet verified.

---

---

## 24. Evidence and reporting rules

- Include links to official documentation and exact source files/sections for important claims.
- When discussing Coucou, cite the exact source paths and inspected commit/release where possible.
- When discussing a third-party framework, link to its official repository/docs and license. Do not merely repeat its marketing promises.
- When stating that you ran a command/test, include the command or concise output, test count/result, and environment. Redact all secrets.
- Label all estimates and measurements as measured, inferred or not yet verified.
- Avoid inflated confidence, unsupported “fully autonomous” claims, or unbounded promises.
- If two architecture options are viable, compare them against this brief and recommend one. Do not leave every decision open.
- Explicitly list every task that cannot be verified inside Arena and the later validation method required.
- Do not claim the final app will be stable merely because one happy-path demo works.

---

---

## 25. What “good outcome” means for Lupy

The long-term target is a coherent, personal, dependable executive-assistant product that:

- Keeps Coucou's familiar visual style while behaving as a new Lupy product.
- Runs smoothly on an 8 GB MacBook Air with about 1 GB of available headroom and **does not run a local LLM**.
- Uses cloud model APIs with clear provider selection, secure credentials, cost controls and understandable privacy boundaries.
- Preserves project knowledge and task state in user-controlled storage, separate from chat history.
- Plans and tracks real work, prioritizes intelligently and proactively follows up.
- Coordinates Arena, Muse, Orin and other tools only where technically supported and authorized.
- Treats agent reports as claims until corroborated by evidence.
- Verifies handoffs, deliverables and computer actions; does not fake progress or success.
- Diagnoses failures, uses bounded retries, changes strategy when needed and recovers safely.
- Adapts task-specific oversight based on demonstrated reliability without compromising permissions.
- Uses approvals for consequential actions and keeps the founder in control of high-impact decisions.
- Survives restart and network failure without losing work or duplicating side effects.
- Has appropriate automated tests, regression checks, security checks, performance checks and documented limitations.
- Can be backed up, exported, updated and moved to a future device without losing the founder's operational history.
- Requires minimal technical effort from the founder during normal use.

This is the desired direction, not a claim that any one tool or model can achieve it without engineering, tests and trade-offs.

---
