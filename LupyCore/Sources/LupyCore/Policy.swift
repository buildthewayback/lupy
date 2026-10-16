// LupyCore — the approval gate. Enforced in code, independent of any model output.
//
// Order of rules (first match wins):
//  1. Forbidden kinds (bypassing MFA/CAPTCHA/security) are always denied.
//  2. Global pause denies everything except reading and Lupy's own record-keeping.
//  3. Access/security changes originating from model or agent content are denied.
//  4. Project "never automate" rules force founder approval (standing approvals ignored).
//  5. Risk-free kinds are allowed.
//  6. Autonomy mode + risk level decide; narrow, unexpired standing approvals can satisfy
//     medium/high (and spend with a cap) — never the "neverStanding" kinds.
// Worker reliability scores are deliberately NOT an input: trust never widens permissions.

public struct PolicyDecision: Equatable, Sendable {
    public enum Verdict: String, Equatable, Sendable { case allow, requireApproval, deny }
    public var verdict: Verdict
    public var reasons: [String]
    public var risk: RiskLevel
    public var matchedStandingApproval: LupyID?

    public var explanation: String { reasons.joined(separator: " ") }
}

public struct PolicyContext: Sendable {
    public var settings: LupySettings
    public var project: Project?
    public var standingApprovals: [StandingApproval]
    public var provider: ProviderConfig?
    public var budgetVerdict: BudgetVerdict?
    public var now: Timestamp

    public init(settings: LupySettings, project: Project?, standingApprovals: [StandingApproval], provider: ProviderConfig? = nil,
                budgetVerdict: BudgetVerdict? = nil, now: Timestamp) {
        self.settings = settings; self.project = project; self.standingApprovals = standingApprovals
        self.provider = provider; self.budgetVerdict = budgetVerdict; self.now = now
    }
}

public enum PolicyEngine {
    public static func evaluate(_ action: ProposedAction, context ctx: PolicyContext) -> PolicyDecision {
        let risk = action.kind.risk
        func decide(_ v: PolicyDecision.Verdict, _ reasons: [String], match: LupyID? = nil) -> PolicyDecision {
            PolicyDecision(verdict: v, reasons: reasons, risk: risk, matchedStandingApproval: match)
        }

        if risk == .forbidden {
            return decide(.deny, ["Lupy never bypasses security controls (MFA, CAPTCHA, access checks)."])
        }
        if ctx.settings.globalPause && risk > .none {
            let why = ctx.settings.pauseReason.isEmpty ? "" : " (\(ctx.settings.pauseReason))"
            return decide(.deny, ["Lupy is paused\(why). Resume to allow actions."])
        }
        if action.originator.isUntrustedContentSource && (action.kind == .grantAccess || action.kind == .changeAccountSecurity) {
            return decide(.deny, ["This request came from model or agent output; access and security changes can only be started by you."])
        }
        if let p = ctx.project, p.status == .archived, risk > .none {
            return decide(.deny, ["Project \(p.name) is archived."])
        }
        if let p = ctx.project, p.neverAutomate.contains(action.kind) {
            return decide(.requireApproval, ["Project rule for \(p.name): “\(action.kind.label)” always needs your approval."])
        }

        // Model calls: consent = provider approved by founder; cost = budget guard.
        if action.kind == .modelCall {
            guard let provider = ctx.provider else { return decide(.deny, ["No cloud model provider is set up."]) }
            guard provider.enabled else { return decide(.deny, ["Provider \(provider.displayName) is disabled."]) }
            guard provider.founderApproved else {
                return decide(.requireApproval, ["You haven't yet allowed Lupy to send data to \(provider.displayName)."])
            }
            switch ctx.budgetVerdict ?? .ok {
            case .ok: break
            case .needsApproval(let why): return decide(.requireApproval, [why])
            case .blocked(let why): return decide(.deny, [why])
            }
            if ctx.settings.autonomy == .observe {
                return decide(.requireApproval, ["Observe mode: Lupy asks before sending anything to a model."])
            }
            return decide(.allow, ["Within budget; \(provider.displayName) is approved by you."])
        }

        if risk == .none { return decide(.allow, ["Only affects Lupy's own records."]) }

        let standing = matchingStandingApproval(action, ctx.standingApprovals, now: ctx.now)

        switch ctx.settings.autonomy {
        case .observe:
            return decide(.requireApproval, ["Observe mode: Lupy only advises; \(action.kind.label.lowercased()) needs your approval."])
        case .prepare:
            if risk == .low { return decide(.allow, ["Drafts are kept inside Lupy until you approve sending them."]) }
            if let sa = standing { return decide(.allow, ["Covered by your standing approval: \(sa.note.isEmpty ? action.kind.label : sa.note)."], match: sa.id) }
            return decide(.requireApproval, ["“\(action.kind.label)” has \(risk.label.lowercased()) risk; in Prepare mode Lupy asks first."])
        case .bounded:
            if risk <= .medium {
                return decide(.allow, ["Within your Act-within-limits setting (\(risk.label.lowercased()) risk)."], match: standing?.id)
            }
            if let sa = standing { return decide(.allow, ["Covered by your standing approval: \(sa.note.isEmpty ? action.kind.label : sa.note)."], match: sa.id) }
            return decide(.requireApproval, ["“\(action.kind.label)” has \(risk.label.lowercased()) risk and no standing approval covers it."])
        }
    }

    public static func matchingStandingApproval(_ action: ProposedAction, _ approvals: [StandingApproval], now: Timestamp) -> StandingApproval? {
        approvals.filter { matches($0, action: action, now: now) }.sorted { $0.createdAt < $1.createdAt }.first
    }

    public static func matches(_ sa: StandingApproval, action: ProposedAction, now: Timestamp) -> Bool {
        guard sa.kind == action.kind, !action.kind.neverStanding, sa.revokedAt == nil, now < sa.expiresAt,
              sa.createdBy.mayGrantPermissions else { return false }
        if let max = sa.maxUses, sa.uses >= max { return false }
        if let p = sa.projectID, p != action.projectID { return false }
        if let w = sa.workerID, w != action.workerID { return false }
        if action.kind == .spendMoney {
            guard let cap = sa.maxCostCents, let cost = action.estimatedCostCents, cost <= cap else { return false }
        } else if let cap = sa.maxCostCents, let cost = action.estimatedCostCents, cost > cap {
            return false
        }
        return targetMatches(sa.targetPattern, action.target)
    }

    public static func targetMatches(_ pattern: String, _ target: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasSuffix("*") { return target.hasPrefix(String(pattern.dropLast())) }
        return pattern == target
    }

    /// Validates a standing approval before it is stored. Only the founder may grant, and scopes must be narrow.
    public static func validateGrant(_ sa: StandingApproval, now: Timestamp) -> String? {
        guard sa.createdBy.mayGrantPermissions else { return "Only you can grant standing approvals." }
        if sa.kind.neverStanding { return "“\(sa.kind.label)” always needs a fresh approval; it cannot be pre-approved." }
        if sa.expiresAt <= now { return "The approval must expire in the future." }
        if sa.expiresAt.since(now) > .days(90) { return "Standing approvals can last at most 90 days." }
        if sa.kind == .spendMoney && (sa.maxCostCents ?? 0) <= 0 { return "Spending approvals need a maximum amount." }
        if sa.kind.risk >= .high && sa.targetPattern == "*" && sa.projectID == nil && sa.workerID == nil {
            return "High-risk approvals must be limited to a project, a worker or a specific target."
        }
        if let m = sa.maxUses, m <= 0 { return "Maximum uses must be at least 1." }
        return nil
    }
}

// MARK: - Budget guard

public enum BudgetVerdict: Equatable, Sendable {
    case ok
    case needsApproval(String)
    case blocked(String)
}

public struct BudgetStatus: Equatable, Sendable {
    public var spentTodayCents: Double
    public var spentMonthCents: Double
    public var dailyCapCents: Double
    public var monthlyCapCents: Double
    public var callsToday: Int
    public var warn: Bool
    public var hardStopped: Bool
    public var remainingTodayCents: Double { max(0, dailyCapCents - spentTodayCents) }
    public var remainingMonthCents: Double { max(0, monthlyCapCents - spentMonthCents) }
}

public enum BudgetGuard {
    public static func status(_ state: LupyState, now: Timestamp) -> BudgetStatus {
        let off = state.settings.utcOffsetMinutes
        let day = now.dayKey(utcOffsetMinutes: off), month = now.monthKey(utcOffsetMinutes: off)
        var today = 0.0, monthTotal = 0.0, calls = 0
        for u in state.usage {
            if u.at.monthKey(utcOffsetMinutes: off) == month { monthTotal += u.costCents }
            if u.at.dayKey(utcOffsetMinutes: off) == day { today += u.costCents; calls += 1 }
        }
        let b = state.budget
        let warn = today >= b.dailyCapCents * b.warnFraction || monthTotal >= b.monthlyCapCents * b.warnFraction
        return BudgetStatus(spentTodayCents: today, spentMonthCents: monthTotal, dailyCapCents: b.dailyCapCents,
                            monthlyCapCents: b.monthlyCapCents, callsToday: calls, warn: warn,
                            hardStopped: today >= b.dailyCapCents || monthTotal >= b.monthlyCapCents)
    }

    /// Checks one prospective call. Hard caps block; large single calls need approval.
    public static func check(estimatedCents: Double, taskID: LupyID?, state: LupyState, now: Timestamp) -> BudgetVerdict {
        let s = status(state, now: now)
        let b = state.budget
        if s.spentMonthCents + estimatedCents > b.monthlyCapCents {
            return .blocked("Monthly model budget (\(TextUtil.formatCents(b.monthlyCapCents))) would be exceeded; \(TextUtil.formatCents(s.spentMonthCents)) spent.")
        }
        if s.spentTodayCents + estimatedCents > b.dailyCapCents {
            return .blocked("Today's model budget (\(TextUtil.formatCents(b.dailyCapCents))) would be exceeded; \(TextUtil.formatCents(s.spentTodayCents)) spent.")
        }
        if let tid = taskID, let t = state.tasks[tid] {
            let cap = t.budgetCents ?? b.perTaskCapCents
            if t.spentCents + estimatedCents > cap {
                return .needsApproval("This task would exceed its budget of \(TextUtil.formatCents(cap)) (\(TextUtil.formatCents(t.spentCents)) spent).")
            }
            let calls = state.usage.filter { $0.taskID == tid }.count
            if calls >= b.maxModelCallsPerTask {
                return .needsApproval("This task already used \(calls) model calls (limit \(b.maxModelCallsPerTask)).")
            }
        }
        if estimatedCents > b.approvalAboveCentsPerCall {
            return .needsApproval("This single model call is estimated at \(TextUtil.formatCents(estimatedCents)), above your \(TextUtil.formatCents(b.approvalAboveCentsPerCall)) per-call limit.")
        }
        return .ok
    }
}
