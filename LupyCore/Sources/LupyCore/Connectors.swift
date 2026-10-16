// LupyCore — connectors: honest capability descriptions, GitHub evidence (requests + parsing),
// claim extraction from worker replies, manual-relay briefs and file-path policy.

public enum ConnectorCatalog {
    public static func defaults() -> [ConnectorStatus] {
        [
            ConnectorStatus(id: "github", name: "GitHub (read-only evidence)", state: .notConnected,
                            capabilities: ["Check branches, commits, pull requests and CI checks to verify delegated coding work"],
                            limitations: ["Read-only: Lupy never pushes, merges or comments", "Needs a fine-grained token with read access to your repositories"],
                            dataSent: "Repository names and branch/PR identifiers are sent to api.github.com.", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "manual-relay", name: "Manual relay (Arena, Muse, ChatGPT/Orin…)", state: .connected,
                            capabilities: ["Lupy prepares the handoff; you paste it; you paste replies back"],
                            limitations: ["Lupy cannot see whether the agent received or read the message — delivery stays “unconfirmed” until a reply or independent evidence appears"],
                            dataSent: "Nothing leaves your Mac automatically.", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "arena-api", name: "Arena direct connection", state: .notConnected,
                            capabilities: [], limitations: ["No supported API is known to Lupy; use Manual relay + GitHub evidence"],
                            dataSent: "—", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "muse-api", name: "Muse direct connection", state: .notConnected,
                            capabilities: [], limitations: ["No supported API is known to Lupy; use Manual relay"],
                            dataSent: "—", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "orin-chatgpt", name: "Orin / ChatGPT conversations", state: .notConnected,
                            capabilities: [], limitations: ["ChatGPT conversations have no API Lupy can read; use Manual relay. (Lupy can use the OpenAI API as its own model provider.)"],
                            dataSent: "—", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "files", name: "Files on this Mac", state: .connected,
                            capabilities: ["Check that a file exists and record its size, date and fingerprint as evidence"],
                            limitations: ["Only inside folders you approve", "Lupy never deletes files"],
                            dataSent: "Nothing; checks happen locally.", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "email", name: "Email", state: .planned, capabilities: [],
                            limitations: ["Not connected in this version — Lupy drafts emails for you to send"], dataSent: "—", lastCheckedAt: nil, lastError: nil),
            ConnectorStatus(id: "social-displate", name: "Social media & Displate", state: .planned, capabilities: [],
                            limitations: ["Not connected — Lupy prepares posts/listings; publishing always needs you"], dataSent: "—", lastCheckedAt: nil, lastError: nil),
        ]
    }
}

// MARK: - GitHub

public enum GitHubQuery: Codable, Equatable, Sendable {
    case branch(repo: String, name: String)
    case pullRequest(repo: String, number: Int)
    case pullsForBranch(repo: String, branch: String)
    case checkRuns(repo: String, ref: String)
    case commit(repo: String, sha: String)

    public var repo: String {
        switch self {
        case .branch(let r, _), .pullRequest(let r, _), .pullsForBranch(let r, _), .checkRuns(let r, _), .commit(let r, _): return r
        }
    }

    public var label: String {
        switch self {
        case .branch(let r, let n): return "branch \(n) in \(r)"
        case .pullRequest(let r, let n): return "PR #\(n) in \(r)"
        case .pullsForBranch(let r, let b): return "pull requests for \(b) in \(r)"
        case .checkRuns(let r, let ref): return "CI checks for \(TextUtil.truncate(ref, 12)) in \(r)"
        case .commit(let r, let s): return "commit \(String(s.prefix(7))) in \(r)"
        }
    }
}

public enum GitHubAPI {
    public static let keychainAccount = "connector.github"

    /// "https://github.com/owner/repo/commit/<sha>" → ("owner/repo", "<sha>")
    public static func repoAndCommit(fromURL url: String) -> (String, String)? {
        guard let r = url.firstRange(of: "github.com/") else { return nil }
        let comps = url[r.upperBound...].split(separator: "/").map(String.init)
        guard comps.count >= 4, comps[2] == "commit", isValidRepo("\(comps[0])/\(comps[1])") else { return nil }
        return ("\(comps[0])/\(comps[1])", comps[3])
    }

    public static func isValidRepo(_ r: String) -> Bool {
        let parts = r.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return parts.allSatisfy { p in !p.isEmpty && p.count <= 100 && p.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." } && p != "." && p != ".." }
    }

    static func enc(_ s: String) -> String {
        var out = ""
        for b in s.utf8 {
            let c = Character(Unicode.Scalar(b))
            if c.isLetter && b < 128 || c.isNumber && b < 128 || c == "-" || c == "_" || c == "." || c == "~" { out.append(c) }
            else { out += "%" + String(b >> 4, radix: 16, uppercase: true) + String(b & 0xF, radix: 16, uppercase: true) }
        }
        return out
    }

    public static func request(_ q: GitHubQuery) -> HTTPRequestSpec? {
        guard isValidRepo(q.repo) else { return nil }
        let base = "https://api.github.com/repos/\(q.repo)"
        let path: String
        switch q {
        case .branch(_, let n): path = "/branches/\(enc(n))"
        case .pullRequest(_, let n): path = "/pulls/\(n)"
        case .pullsForBranch(let r, let b): path = "/pulls?state=all&per_page=10&head=\(enc(String(r.split(separator: "/")[0]) + ":" + b))"
        case .checkRuns(_, let ref): path = "/commits/\(enc(ref))/check-runs?per_page=50"
        case .commit(_, let s): path = "/commits/\(enc(s))"
        }
        return HTTPRequestSpec(method: "GET", url: base + path,
                               headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"],
                               body: [], auth: AuthPlacement(header: "Authorization", prefix: "Bearer "),
                               keychainAccount: keychainAccount, timeoutSeconds: 30)
    }

    /// Converts a GitHub response into independent evidence for a task. A 404 for something the worker
    /// claimed exists is a contradiction; network/auth problems are inconclusive, never contradictions.
    public static func evidence(for q: GitHubQuery, status: Int, body: [UInt8], taskID: LupyID, handoffID: LupyID?, ids: IDGenerator, now: Timestamp) -> [Evidence] {
        let src = Principal.connector("github")
        func ev(_ kind: EvidenceKind, _ verdict: EvidenceVerdict, _ summary: String, _ ref: String?) -> Evidence {
            var e = Evidence(id: ids.next("evd"), taskID: taskID, kind: kind, summary: summary, source: src,
                             independence: .independent, verdict: verdict, reference: ref, observedAt: now)
            e.handoffID = handoffID
            return e
        }
        let json = try? JSONParser.parse(bytes: body)
        if status == 404 {
            switch q {
            case .branch(let r, let n): return [ev(.commit, .contradicts, "Branch “\(n)” does not exist in \(r).", "https://github.com/\(r)/tree/\(n)")]
            case .pullRequest(let r, let n): return [ev(.pullRequest, .contradicts, "PR #\(n) does not exist in \(r).", "https://github.com/\(r)/pull/\(n)")]
            case .commit(let r, let s): return [ev(.commit, .contradicts, "Commit \(String(s.prefix(7))) not found in \(r).", nil)]
            default: return [ev(.observation, .inconclusive, "GitHub returned 404 for \(q.label).", nil)]
            }
        }
        guard (200..<300).contains(status), let j = json else {
            return [ev(.observation, .inconclusive, "Could not check \(q.label) (HTTP \(status)). Not treated as a failure.", nil)]
        }
        switch q {
        case .branch(let r, let n):
            let sha = j["commit"]?["sha"]?.stringValue ?? ""
            let date = j["commit"]?["commit"]?["committer"]?["date"]?.stringValue ?? ""
            return [ev(.commit, .supports, "Branch “\(n)” exists; latest commit \(String(sha.prefix(7)))\(date.isEmpty ? "" : " at \(date)").", "https://github.com/\(r)/commit/\(sha)")]
        case .pullRequest(let r, let n):
            return [prEvidence(j, repo: r, number: n, make: ev)]
        case .pullsForBranch(let r, let b):
            let prs = j.arrayValue ?? []
            if prs.isEmpty { return [ev(.pullRequest, .inconclusive, "No pull request found for branch \(b) yet.", nil)] }
            return prs.prefix(1).map { prEvidence($0, repo: r, number: $0["number"]?.intValue ?? 0, make: ev) }
        case .checkRuns(let r, let ref):
            let runs = j["check_runs"]?.arrayValue ?? []
            if runs.isEmpty { return [ev(.ciResult, .inconclusive, "No CI checks reported for \(String(ref.prefix(7))) yet.", "https://github.com/\(r)/commit/\(ref)")] }
            let pending = runs.filter { $0["status"]?.stringValue != "completed" }.count
            let failed = runs.filter { ["failure", "timed_out", "cancelled", "action_required", "startup_failure"].contains($0["conclusion"]?.stringValue ?? "") }
            if !failed.isEmpty {
                let names = failed.prefix(3).compactMap { $0["name"]?.stringValue }.joined(separator: ", ")
                return [ev(.ciResult, .contradicts, "\(failed.count) of \(runs.count) CI checks failed (\(names)).", "https://github.com/\(r)/commit/\(ref)")]
            }
            if pending > 0 { return [ev(.ciResult, .inconclusive, "\(pending) of \(runs.count) CI checks still running.", "https://github.com/\(r)/commit/\(ref)")] }
            return [ev(.ciResult, .supports, "All \(runs.count) CI checks passed.", "https://github.com/\(r)/commit/\(ref)")]
        case .commit(let r, let s):
            let msg = j["commit"]?["message"]?.stringValue ?? ""
            return [ev(.commit, .supports, "Commit \(String(s.prefix(7))) exists: “\(TextUtil.truncate(msg, 80))”.", "https://github.com/\(r)/commit/\(s)")]
        }
    }

    static func prEvidence(_ j: JSONValue, repo: String, number: Int, make: (EvidenceKind, EvidenceVerdict, String, String?) -> Evidence) -> Evidence {
        let state = j["state"]?.stringValue ?? "unknown"
        let merged = j["merged"]?.boolValue == true || (j["merged_at"]?.stringValue.map { !$0.isEmpty } ?? false)
        let title = j["title"]?.stringValue ?? ""
        let head = j["head"]?["sha"]?.stringValue ?? ""
        let desc = merged ? "merged" : state
        var e = make(.pullRequest, .supports, "PR #\(number) “\(TextUtil.truncate(title, 60))” is \(desc).", "https://github.com/\(repo)/pull/\(number)")
        if !head.isEmpty { e.contentHash = head }
        return e
    }
}

// MARK: - Claims in worker replies (claims are not evidence; they tell Lupy what to check)

public enum ExtractedClaim: Equatable, Sendable {
    case pullRequest(repo: String, number: Int)
    case commit(sha: String)
    case branch(name: String)
    case completion
    case sent
    case deployed
    case blocked
    case question
}

public enum ClaimExtractor {
    public static func extract(_ text: String) -> [ExtractedClaim] {
        var out: [ExtractedClaim] = []
        let lower = text.lowercased()
        // GitHub PR links
        var rest = text[...]
        while let r = rest.firstRange(of: "github.com/") {
            let after = rest[r.upperBound...]
            let pathChars = after.prefix { !$0.isWhitespace && $0 != ")" && $0 != "]" && $0 != ">" && $0 != "," && $0 != "\"" }
            let comps = pathChars.split(separator: "/").map(String.init)
            if comps.count >= 4, comps[2] == "pull" || comps[2] == "pulls", let n = Int(comps[3].prefix { $0.isNumber }) {
                let claim = ExtractedClaim.pullRequest(repo: "\(comps[0])/\(comps[1])", number: n)
                if !out.contains(claim) { out.append(claim) }
            } else if comps.count >= 4, comps[2] == "commit" {
                let sha = String(comps[3].prefix { $0.isHexDigit })
                if sha.count >= 7 { out.append(.commit(sha: sha.lowercased())) }
            }
            rest = after
        }
        // Branch mentions: "branch `x`", "branch: x", "pushed to x"
        let words = text.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        for (i, w) in words.enumerated() {
            let lw = w.lowercased().lupyTrim(":,.")
            if (lw == "branch" || lw == "pushed" && i + 2 < words.count && words[i + 1].lowercased() == "to"), i + 1 < words.count {
                var candidate = lw == "branch" ? words[i + 1] : words[i + 2]
                candidate = candidate.lupyTrim("`'\"*:,.()")
                if candidate.count >= 2, candidate.contains("/") || candidate.contains("-") || candidate.contains("_"), !candidate.hasPrefix("http") {
                    let claim = ExtractedClaim.branch(name: candidate)
                    if !out.contains(claim) { out.append(claim) }
                }
            }
            // bare commit SHAs (7–40 hex chars containing at least one digit and one letter)
            let token = w.lupyTrim("`'\"*:,.()[]")
            if token.count >= 7 && token.count <= 40 && token.allSatisfy(\.isHexDigit) && token.contains(where: \.isNumber) && token.contains(where: \.isLetter) {
                let claim = ExtractedClaim.commit(sha: token.lowercased())
                if !out.contains(claim) { out.append(claim) }
            }
        }
        if ["done", "completed", "finished", "implemented", "it's ready", "is ready", "all set", "shipped", "merged"].contains(where: { lower.contains($0) }) { out.append(.completion) }
        if ["sent it", "have sent", "emailed", "messaged", "posted"].contains(where: { lower.contains($0) }) { out.append(.sent) }
        if ["deployed", "live now", "is live"].contains(where: { lower.contains($0) }) { out.append(.deployed) }
        if ["blocked", "can't proceed", "cannot proceed", "stuck", "need access", "waiting on"].contains(where: { lower.contains($0) }) { out.append(.blocked) }
        if text.contains("?") { out.append(.question) }
        return out
    }
}

extension String {
    func lupyTrim(_ set: String) -> String {
        var s = Substring(self)
        while let f = s.first, set.contains(f) { s.removeFirst() }
        while let l = s.last, set.contains(l) { s.removeLast() }
        return String(s)
    }
}

// MARK: - Manual relay brief

public enum HandoffBriefWriter {
    public static func make(task: LupyTask, project: Project?, worker: Worker, due: Timestamp?, checkpoint: Timestamp?, reference: String) -> HandoffBrief {
        var constraints = ["Work only on the scope below; ask if anything is unclear.",
                           "Do not merge into main/master, publish, spend money or contact anyone unless this brief says so."]
        if task.kind == .coding, let repo = project?.repository { constraints.append("Repository: \(repo). Push to a feature branch and open a pull request.") }
        let evidence: [String] = task.kind == .coding
            ? ["Branch name", "Pull request link", "Commit hash(es)", "Test/CI status"]
            : ["Link or file name of the deliverable", "What you checked and how", "Anything left undone"]
        return HandoffBrief(objective: task.title, scope: task.details.isEmpty ? task.title : task.details, constraints: constraints,
                            projectRules: project?.rules.map(\.text) ?? [], acceptance: VerificationEngine.criteria(for: task).map(\.text),
                            evidenceRequested: evidence, due: due, checkpoint: checkpoint, contextNotes: "", reference: reference)
    }

    public static func render(_ b: HandoffBrief, workerName: String, utcOffsetMinutes: Int) -> String {
        func local(_ t: Timestamp) -> String { String(Timestamp(millis: t.millis + Int64(utcOffsetMinutes) * 60_000).iso8601.prefix(16)).replacing("T", with: " ") + " (local)" }
        var s = "Handoff from Lupy (on behalf of the founder) — ref \(b.reference)\n\n"
        s += "Objective: \(b.objective)\n\nScope:\n\(b.scope)\n"
        if !b.constraints.isEmpty { s += "\nConstraints:\n" + b.constraints.map { "- \($0)" }.joined(separator: "\n") + "\n" }
        if !b.projectRules.isEmpty { s += "\nProject rules:\n" + b.projectRules.map { "- \($0)" }.joined(separator: "\n") + "\n" }
        s += "\nDone means (acceptance criteria):\n" + b.acceptance.map { "- \($0)" }.joined(separator: "\n") + "\n"
        s += "\nWhen you report back, include:\n" + b.evidenceRequested.map { "- \($0)" }.joined(separator: "\n") + "\n"
        if let c = b.checkpoint { s += "\nCheckpoint: please send a short progress update by \(local(c)).\n" }
        if let d = b.due { s += "Due: \(local(d)).\n" }
        s += "\nPlease reply with the reference \(b.reference) so Lupy can match your answer."
        return s
    }
}

// MARK: - File evidence policy

public enum FilePolicy {
    /// Normalizes a POSIX path and checks it lies inside one of the approved folders.
    public static func isAllowed(_ path: String, approvedRoots: [String]) -> Bool {
        guard let norm = normalize(path) else { return false }
        return approvedRoots.compactMap(normalize).contains { root in norm == root || norm.hasPrefix(root.hasSuffix("/") ? root : root + "/") }
    }

    public static func normalize(_ path: String) -> String? {
        guard path.hasPrefix("/") else { return nil }
        var stack: [Substring] = []
        for comp in path.split(separator: "/") {
            if comp == "." || comp.isEmpty { continue }
            if comp == ".." { if stack.isEmpty { return nil }; stack.removeLast(); continue }
            stack.append(comp)
        }
        return "/" + stack.joined(separator: "/")
    }
}
