// LupyCore — forward-compatible decoding for persisted root types.
// Synthesized Decodable treats every non-optional property as a required key, so adding a field
// would make older snapshots unreadable. These decoders default any missing field instead.

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default d: @autoclosure () -> T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? d()
    }
}

extension LupyState {
    enum CodingKeys: String, CodingKey {
        case settings, projects, goals, plans, tasks, evidence, verifications, handoffs, workers, reliability, memory, decisions,
             approvals, standingApprovals, actions, providers, routing, budget, usage, notices, connectors, drafts, lastSeq,
             lastEventAt, schema
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        settings = try c.value(.settings, default: LupySettings())
        projects = try c.value(.projects, default: [:])
        goals = try c.value(.goals, default: [:])
        plans = try c.value(.plans, default: [:])
        tasks = try c.value(.tasks, default: [:])
        evidence = try c.value(.evidence, default: [:])
        verifications = try c.value(.verifications, default: [:])
        handoffs = try c.value(.handoffs, default: [:])
        workers = try c.value(.workers, default: [:])
        reliability = try c.value(.reliability, default: [:])
        memory = try c.value(.memory, default: [:])
        decisions = try c.value(.decisions, default: [:])
        approvals = try c.value(.approvals, default: [:])
        standingApprovals = try c.value(.standingApprovals, default: [:])
        actions = try c.value(.actions, default: [:])
        providers = try c.value(.providers, default: [:])
        routing = try c.value(.routing, default: RoutingPolicy())
        budget = try c.value(.budget, default: BudgetPolicy())
        usage = try c.value(.usage, default: [])
        notices = try c.value(.notices, default: [:])
        connectors = try c.value(.connectors, default: [:])
        drafts = try c.value(.drafts, default: [:])
        lastSeq = try c.value(.lastSeq, default: 0)
        lastEventAt = try c.decodeIfPresent(Timestamp.self, forKey: .lastEventAt)
        schema = try c.value(.schema, default: LupyEvent.currentSchema)
    }
}

extension LupySettings {
    enum CodingKeys: String, CodingKey {
        case autonomy, globalPause, pauseReason, quietHours, maxNotificationsPerHour, utcOffsetMinutes, dailyReviewMinute,
             followUp, dataSharing, onboardingComplete, founderName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        autonomy = try c.value(.autonomy, default: .prepare)
        globalPause = try c.value(.globalPause, default: false)
        pauseReason = try c.value(.pauseReason, default: "")
        quietHours = try c.value(.quietHours, default: QuietHours())
        maxNotificationsPerHour = try c.value(.maxNotificationsPerHour, default: 4)
        utcOffsetMinutes = try c.value(.utcOffsetMinutes, default: 330)
        dailyReviewMinute = try c.value(.dailyReviewMinute, default: 8 * 60 + 30)
        followUp = try c.value(.followUp, default: FollowUpPolicy())
        dataSharing = try c.value(.dataSharing, default: DataSharingPolicy())
        onboardingComplete = try c.value(.onboardingComplete, default: false)
        founderName = try c.value(.founderName, default: "")
    }
}

extension BudgetPolicy {
    enum CodingKeys: String, CodingKey {
        case monthlyCapCents, dailyCapCents, perTaskCapCents, approvalAboveCentsPerCall, maxOutputTokensPerCall,
             maxModelCallsPerTask, maxRetriesPerCall, warnFraction
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        monthlyCapCents = try c.value(.monthlyCapCents, default: 1000)
        dailyCapCents = try c.value(.dailyCapCents, default: 150)
        perTaskCapCents = try c.value(.perTaskCapCents, default: 50)
        approvalAboveCentsPerCall = try c.value(.approvalAboveCentsPerCall, default: 20)
        maxOutputTokensPerCall = try c.value(.maxOutputTokensPerCall, default: 1500)
        maxModelCallsPerTask = try c.value(.maxModelCallsPerTask, default: 12)
        maxRetriesPerCall = try c.value(.maxRetriesPerCall, default: 2)
        warnFraction = try c.value(.warnFraction, default: 0.8)
    }
}
