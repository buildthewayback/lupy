// LupyCore — bounded retries, strategy changes and recurring-failure detection.

public enum RetryDecision: Equatable, Sendable {
    case retry(after: Millis, reason: String)
    case switchRoute(reason: String)
    case escalate(reason: String)
}

public enum RetryPolicy {
    /// `attempt` is the number of attempts already made (1 after the first failure).
    public static func decide(_ error: ErrorInfo, attempt: Int, maxRetries: Int, hasAlternative: Bool, seed: UInt64 = 1) -> RetryDecision {
        var rng = SplitMix64(seed: seed &+ UInt64(attempt))
        func backoff(_ baseSeconds: Double) -> Millis {
            var s = baseSeconds
            for _ in 1..<max(1, attempt) { s *= 2 }
            s = min(s, 300)
            let jitter = Double(rng.next() % 1000) / 1000 * s * 0.2
            return Millis(Int64((s + jitter) * 1000))
        }
        switch error.category {
        case .auth:
            return .escalate(reason: "The provider rejected the key. Please check or replace it in Settings → Providers.")
        case .quotaExceeded:
            return hasAlternative ? .switchRoute(reason: "Provider credit/quota exhausted; trying another approved provider.")
                                  : .escalate(reason: "The provider's credit or quota is exhausted. Top up or choose another provider.")
        case .invalidRequest, .contentFiltered:
            return hasAlternative ? .switchRoute(reason: "The request was rejected (\(error.category.label.lowercased())); trying a different route.")
                                  : .escalate(reason: "The request was rejected: \(error.message)")
        case .contextTooLong:
            return .switchRoute(reason: "Too much context; Lupy will shorten it or use a model with a larger window.")
        case .modelUnavailable:
            return hasAlternative ? .switchRoute(reason: "Model unavailable; using another approved model.")
                                  : .escalate(reason: "The selected model is unavailable. Pick another model in Settings.")
        case .permanent:
            return .escalate(reason: "Permanent failure: \(error.message)")
        case .rateLimited:
            if attempt > maxRetries { return hasAlternative ? .switchRoute(reason: "Still rate limited after \(attempt) attempts.") : .escalate(reason: "Rate limited repeatedly.") }
            if let ra = error.retryAfterMillis, ra > 0 { return .retry(after: Millis(min(ra, 600_000)), reason: "Rate limited; waiting as the provider asked.") }
            return .retry(after: backoff(10), reason: "Rate limited; backing off.")
        case .transient, .timeout, .network, .unknown:
            if attempt > maxRetries {
                return hasAlternative ? .switchRoute(reason: "\(error.category.label) persisted after \(attempt) attempts.")
                                      : .escalate(reason: "\(error.category.label) persisted after \(attempt) attempts: \(error.message)")
            }
            return .retry(after: backoff(error.category == .network ? 30 : 4), reason: "\(error.category.label); retrying.")
        }
    }
}

public struct FailurePattern: Equatable, Sendable {
    public var signature: String
    public var count: Int
    public var advice: String
}

public enum FailurePatterns {
    /// Same provider + error category ≥ 3 times in 24 h is a recurring failure, not bad luck.
    public static func detect(_ usage: [UsageRecord], now: Timestamp) -> [FailurePattern] {
        var counts: [String: Int] = [:]
        for u in usage where !u.ok && now.since(u.at) < .hours(24) {
            counts["\(u.providerID)|\(u.errorCategory?.rawValue ?? "unknown")", default: 0] += 1
        }
        return counts.filter { $0.value >= 3 }.sorted { $0.key < $1.key }.map { key, n in
            let parts = key.split(separator: "|").map(String.init)
            let cat = ErrorCategory(rawValue: parts.count > 1 ? parts[1] : "unknown") ?? .unknown
            return FailurePattern(signature: key, count: n,
                                  advice: "\(parts[0]) failed \(n) times today (\(cat.label.lowercased())). Lupy will prefer another approved provider; check Settings → Providers.")
        }
    }
}
