// LupyCore — provider-neutral cloud model access.
// Adapters are pure: they build HTTP request specs and parse responses. The macOS shell performs
// the network call and inserts the API key from the Keychain at send time (auth placement), so
// keys never enter LupyCore, its events, logs, prompts or backups.

extension ErrorInfo: Error {}

public enum LLMRole: String, Codable, Sendable { case system, user, assistant }

public struct LLMMessage: Codable, Equatable, Sendable {
    public var role: LLMRole
    public var content: String
    public init(_ role: LLMRole, _ content: String) { self.role = role; self.content = content }
}

public struct LLMRequest: Codable, Equatable, Sendable {
    public var purpose: TaskClass
    public var messages: [LLMMessage]
    public var maxOutputTokens: Int
    public var temperature: Double?
    public var jsonMode: Bool
    public init(purpose: TaskClass, messages: [LLMMessage], maxOutputTokens: Int, temperature: Double? = nil, jsonMode: Bool = false) {
        self.purpose = purpose; self.messages = messages; self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature; self.jsonMode = jsonMode
    }
    public var systemText: String { messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n") }
    public var characterCount: Int { messages.reduce(0) { $0 + $1.content.count } }
}

public struct LLMResponse: Equatable, Sendable {
    public var text: String
    public var inputTokens: Int
    public var outputTokens: Int
    public var finishReason: String
    public var truncated: Bool
    public var modelID: String
}

public struct AuthPlacement: Codable, Equatable, Sendable {
    public var header: String
    public var prefix: String
}

public struct HTTPRequestSpec: Codable, Equatable, Sendable {
    public var method: String
    public var url: String
    public var headers: [String: String]
    public var body: [UInt8]
    public var auth: AuthPlacement?
    public var keychainAccount: String?
    public var timeoutSeconds: Double
    public var bodyText: String { String(decoding: body, as: UTF8.self) }
}

public enum ProviderAPI {
    static func base(_ c: ProviderConfig) -> String {
        var b = TextUtil.trimmed(c.baseURL)
        while b.hasSuffix("/") { b.removeLast() }
        return b
    }

    static func auth(_ kind: ProviderKind) -> AuthPlacement {
        switch kind {
        case .openAI, .openAICompatible: return AuthPlacement(header: "Authorization", prefix: "Bearer ")
        case .anthropic: return AuthPlacement(header: "x-api-key", prefix: "")
        case .gemini: return AuthPlacement(header: "x-goog-api-key", prefix: "")
        }
    }

    static func commonHeaders(_ kind: ProviderKind) -> [String: String] {
        var h = ["Content-Type": "application/json", "Accept": "application/json"]
        if kind == .anthropic { h["anthropic-version"] = "2023-06-01" }
        return h
    }

    public static func buildChat(_ c: ProviderConfig, modelID: String, request r: LLMRequest) -> HTTPRequestSpec {
        var body: [String: JSONValue] = [:]
        let url: String
        switch c.kind {
        case .openAI, .openAICompatible:
            url = base(c) + "/chat/completions"
            body["model"] = .string(modelID)
            body["messages"] = .array(r.messages.map { ["role": .string($0.role.rawValue), "content": .string($0.content)] })
            if c.kind == .openAI {
                // Newer OpenAI models use max_completion_tokens and reject non-default temperature.
                body["max_completion_tokens"] = .number(Double(r.maxOutputTokens))
            } else {
                body["max_tokens"] = .number(Double(r.maxOutputTokens))
                if let t = r.temperature { body["temperature"] = .number(t) }
            }
            if r.jsonMode { body["response_format"] = ["type": "json_object"] }
        case .anthropic:
            url = base(c) + "/messages"
            body["model"] = .string(modelID)
            body["max_tokens"] = .number(Double(r.maxOutputTokens))
            let sys = r.systemText
            if !sys.isEmpty { body["system"] = .string(sys) }
            body["messages"] = .array(mergedTurns(r.messages).map { ["role": .string($0.role.rawValue), "content": .string($0.content)] })
            if let t = r.temperature { body["temperature"] = .number(t) }
        case .gemini:
            url = base(c) + "/models/" + modelID + ":generateContent"
            body["contents"] = .array(mergedTurns(r.messages).map {
                ["role": .string($0.role == .assistant ? "model" : "user"), "parts": [["text": .string($0.content)]]]
            })
            let sys = r.systemText
            if !sys.isEmpty { body["systemInstruction"] = ["parts": [["text": .string(sys)]]] }
            var gen: [String: JSONValue] = ["maxOutputTokens": .number(Double(r.maxOutputTokens))]
            if let t = r.temperature { gen["temperature"] = .number(t) }
            if r.jsonMode { gen["responseMimeType"] = "application/json" }
            body["generationConfig"] = .object(gen)
        }
        return HTTPRequestSpec(method: "POST", url: url, headers: commonHeaders(c.kind), body: JSONWriter.bytes(.object(body)),
                               auth: auth(c.kind), keychainAccount: c.keychainAccount, timeoutSeconds: 90)
    }

    /// Anthropic/Gemini need alternating user/assistant turns without system messages.
    static func mergedTurns(_ messages: [LLMMessage]) -> [LLMMessage] {
        var out: [LLMMessage] = []
        for m in messages where m.role != .system {
            if let last = out.last, last.role == m.role { out[out.count - 1].content += "\n\n" + m.content }
            else { out.append(m) }
        }
        if out.first?.role == .assistant { out.insert(LLMMessage(.user, "(context)"), at: 0) }
        if out.isEmpty { out.append(LLMMessage(.user, "")) }
        return out
    }

    public static func parseChat(_ kind: ProviderKind, status: Int, headers: [String: String], body: [UInt8], modelID: String, now: Timestamp) -> Result<LLMResponse, ErrorInfo> {
        let json = try? JSONParser.parse(bytes: body)
        guard (200..<300).contains(status), let j = json else {
            return .failure(classifyError(kind, status: status, headers: headers, json: json, raw: body, now: now))
        }
        switch kind {
        case .openAI, .openAICompatible:
            guard let choice = j["choices"]?[0] else { return .failure(ErrorInfo(category: .unknown, message: "No choices in response", at: now)) }
            let text = choice["message"]?["content"]?.stringValue ?? ""
            let finish = choice["finish_reason"]?.stringValue ?? ""
            if finish == "content_filter" { return .failure(ErrorInfo(category: .contentFiltered, message: "Response blocked by provider filter", at: now)) }
            return .success(LLMResponse(text: text, inputTokens: j["usage"]?["prompt_tokens"]?.intValue ?? 0,
                                        outputTokens: j["usage"]?["completion_tokens"]?.intValue ?? 0, finishReason: finish,
                                        truncated: finish == "length", modelID: j["model"]?.stringValue ?? modelID))
        case .anthropic:
            let parts = j["content"]?.arrayValue ?? []
            let text = parts.compactMap { $0["type"]?.stringValue == "text" ? $0["text"]?.stringValue : nil }.joined()
            let stop = j["stop_reason"]?.stringValue ?? ""
            if stop == "refusal" { return .failure(ErrorInfo(category: .contentFiltered, message: "Model refused", at: now)) }
            return .success(LLMResponse(text: text, inputTokens: j["usage"]?["input_tokens"]?.intValue ?? 0,
                                        outputTokens: j["usage"]?["output_tokens"]?.intValue ?? 0, finishReason: stop,
                                        truncated: stop == "max_tokens", modelID: j["model"]?.stringValue ?? modelID))
        case .gemini:
            guard let cand = j["candidates"]?[0] else {
                let block = j["promptFeedback"]?["blockReason"]?.stringValue
                return .failure(ErrorInfo(category: block != nil ? .contentFiltered : .unknown, message: block ?? "No candidates", at: now))
            }
            let finish = cand["finishReason"]?.stringValue ?? ""
            if finish == "SAFETY" || finish == "PROHIBITED_CONTENT" || finish == "BLOCKLIST" {
                return .failure(ErrorInfo(category: .contentFiltered, message: "Blocked by Gemini safety filter (\(finish))", at: now))
            }
            let text = (cand["content"]?["parts"]?.arrayValue ?? []).compactMap { $0["text"]?.stringValue }.joined()
            let usage = j["usageMetadata"]
            let out = (usage?["candidatesTokenCount"]?.intValue ?? 0) + (usage?["thoughtsTokenCount"]?.intValue ?? 0)
            return .success(LLMResponse(text: text, inputTokens: usage?["promptTokenCount"]?.intValue ?? 0, outputTokens: out,
                                        finishReason: finish, truncated: finish == "MAX_TOKENS", modelID: modelID))
        }
    }

    public static func classifyError(_ kind: ProviderKind, status: Int, headers: [String: String], json: JSONValue?, raw: [UInt8], now: Timestamp) -> ErrorInfo {
        let errObj = json?["error"]
        let message = errObj?["message"]?.stringValue ?? errObj?.stringValue ?? TextUtil.truncate(String(decoding: raw.prefix(300), as: UTF8.self), 300)
        let code = (errObj?["code"]?.stringValue ?? errObj?["type"]?.stringValue ?? errObj?["status"]?.stringValue ?? "").lowercased()
        var retryAfter: Int64? = nil
        for (k, v) in headers where k.lowercased() == "retry-after" {
            if let secs = Double(TextUtil.trimmed(v)) { retryAfter = Int64(secs * 1000) }
        }
        let lowerMsg = message.lowercased()
        let category: ErrorCategory
        if status == 0 { category = .network }
        else if code.contains("context_length") || lowerMsg.contains("context length") || lowerMsg.contains("too many tokens") || lowerMsg.contains("prompt is too long") { category = .contextTooLong }
        else if code.contains("insufficient_quota") || lowerMsg.contains("credit balance") || lowerMsg.contains("quota") && status != 429 || code == "resource_exhausted" && lowerMsg.contains("billing") { category = .quotaExceeded }
        else if status == 401 || code.contains("invalid_api_key") || code.contains("authentication") || code == "unauthenticated" { category = .auth }
        else if status == 403 || code.contains("permission") { category = lowerMsg.contains("api key") ? .auth : .permanent }
        else if status == 404 || code.contains("not_found") || code.contains("model_not_found") { category = .modelUnavailable }
        else if status == 429 || code.contains("rate_limit") || code == "resource_exhausted" { category = code.contains("insufficient_quota") ? .quotaExceeded : .rateLimited }
        else if status == 408 || status == 504 { category = .timeout }
        else if status == 529 || status >= 500 || code.contains("overloaded") || code == "unavailable" { category = .transient }
        else if status == 400 || status == 422 || code.contains("invalid") { category = .invalidRequest }
        else { category = .unknown }
        let (clean, _) = Redactor.redact(message)
        return ErrorInfo(category: category, message: "HTTP \(status): \(TextUtil.truncate(clean, 280))", at: now, retryAfterMillis: retryAfter)
    }

    public static func buildListModels(_ c: ProviderConfig) -> HTTPRequestSpec {
        HTTPRequestSpec(method: "GET", url: base(c) + "/models", headers: commonHeaders(c.kind), body: [], auth: auth(c.kind),
                        keychainAccount: c.keychainAccount, timeoutSeconds: 30)
    }

    public static func parseListModels(_ kind: ProviderKind, status: Int, body: [UInt8], now: Timestamp) -> Result<[String], ErrorInfo> {
        let json = try? JSONParser.parse(bytes: body)
        guard (200..<300).contains(status), let j = json else {
            return .failure(classifyError(kind, status: status, headers: [:], json: json, raw: body, now: now))
        }
        switch kind {
        case .gemini:
            let models = (j["models"]?.arrayValue ?? []).filter { m in
                (m["supportedGenerationMethods"]?.arrayValue ?? []).contains(.string("generateContent"))
            }.compactMap { $0["name"]?.stringValue }.map { $0.hasPrefix("models/") ? String($0.dropFirst(7)) : $0 }
            return .success(models.sorted())
        default:
            return .success((j["data"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }.sorted())
        }
    }
}

// MARK: - Cost estimation and routing

public enum CostEstimator {
    /// Conservative: ~3.5 characters per token for English prose and JSON.
    public static func tokens(forCharacters n: Int) -> Int { (n * 2 + 6) / 7 }

    public static func cents(inputTokens: Int, outputTokens: Int, model: ModelSpec) -> Double {
        Double(inputTokens) / 1_000_000 * model.inputCentsPerMTok + Double(outputTokens) / 1_000_000 * model.outputCentsPerMTok
    }

    /// Worst case for budget checks: full input + the maximum allowed output.
    public static func worstCaseCents(_ r: LLMRequest, model: ModelSpec) -> Double {
        cents(inputTokens: tokens(forCharacters: r.characterCount), outputTokens: min(r.maxOutputTokens, model.maxOutputTokens), model: model)
    }
}

public struct RouteChoice: Equatable, Sendable {
    public var provider: ProviderConfig
    public var model: ModelSpec
    public var explanation: String
    public var ref: ModelRef { ModelRef(providerID: provider.id, modelID: model.id) }
}

public enum ModelRouter {
    public static func usable(_ s: LupyState) -> [(ProviderConfig, ModelSpec)] {
        s.providers.values.filter { $0.enabled && $0.founderApproved && $0.hasKey }
            .sorted { $0.id < $1.id }
            .flatMap { p in p.models.filter(\.enabled).map { (p, $0) } }
    }

    /// Preferred model if usable, otherwise the best usable one for the purpose. Never a non-approved provider.
    public static func route(_ purpose: TaskClass, state s: LupyState, excluding: Set<ModelRef> = []) -> RouteChoice? {
        let candidates = usable(s).filter { !excluding.contains(ModelRef(providerID: $0.0.id, modelID: $0.1.id)) }
        guard !candidates.isEmpty else { return nil }
        if let pref = s.routing.preferred[purpose.rawValue],
           let hit = candidates.first(where: { $0.0.id == pref.providerID && $0.1.id == pref.modelID }) {
            return RouteChoice(provider: hit.0, model: hit.1, explanation: "Your preferred model for \(purpose.label.lowercased()).")
        }
        if !excluding.isEmpty && !s.routing.allowFallback { return nil }
        let strong = purpose == .planning || purpose == .verifying
        let sorted = candidates.sorted { a, b in
            let pa = a.1.outputCentsPerMTok, pb = b.1.outputCentsPerMTok
            return strong ? pa > pb : pa < pb
        }
        let pick = sorted[0]
        let why = strong ? "Most capable approved model (by price tier) for \(purpose.label.lowercased())."
                         : "Lowest-cost approved model for \(purpose.label.lowercased())."
        return RouteChoice(provider: pick.0, model: pick.1, explanation: excluding.isEmpty ? why : "Fallback after a failure: " + why)
    }
}

public enum ProviderCatalog {
    /// Starting points only — disabled, unapproved, keyless. Prices are editable estimates (US cents per
    /// million tokens) captured for the build date; Lupy labels costs as estimates. Model names change;
    /// "Refresh models" lists what the provider actually offers for the founder's key.
    public static func defaults(now: Timestamp) -> [ProviderConfig] {
        func p(_ id: String, _ kind: ProviderKind, _ name: String, _ url: String, _ models: [ModelSpec], _ notice: String) -> ProviderConfig {
            ProviderConfig(id: id, kind: kind, displayName: name, baseURL: url, keychainAccount: "provider.\(id)", models: models,
                           enabled: false, founderApproved: false, hasKey: false, priceAsOf: "2026-10 (estimate — verify)",
                           dataNotice: notice, createdAt: now)
        }
        return [
            p("openai", .openAI, "OpenAI", "https://api.openai.com/v1", [
                ModelSpec(id: "gpt-5-mini", displayName: "GPT-5 mini", inputCentsPerMTok: 25, outputCentsPerMTok: 200, contextTokens: 400_000, maxOutputTokens: 8000),
                ModelSpec(id: "gpt-5", displayName: "GPT-5", inputCentsPerMTok: 125, outputCentsPerMTok: 1000, contextTokens: 400_000, maxOutputTokens: 8000),
            ], "Requests go to api.openai.com under OpenAI's API data terms."),
            p("anthropic", .anthropic, "Anthropic", "https://api.anthropic.com/v1", [
                ModelSpec(id: "claude-haiku-4-5", displayName: "Claude Haiku 4.5", inputCentsPerMTok: 100, outputCentsPerMTok: 500, contextTokens: 200_000, maxOutputTokens: 8000),
                ModelSpec(id: "claude-sonnet-4-5", displayName: "Claude Sonnet 4.5", inputCentsPerMTok: 300, outputCentsPerMTok: 1500, contextTokens: 200_000, maxOutputTokens: 8000),
            ], "Requests go to api.anthropic.com under Anthropic's API data terms."),
            p("gemini", .gemini, "Google Gemini", "https://generativelanguage.googleapis.com/v1beta", [
                ModelSpec(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", inputCentsPerMTok: 30, outputCentsPerMTok: 250, contextTokens: 1_000_000, maxOutputTokens: 8000),
                ModelSpec(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", inputCentsPerMTok: 125, outputCentsPerMTok: 1000, contextTokens: 1_000_000, maxOutputTokens: 8000),
            ], "Requests go to generativelanguage.googleapis.com. Note: Google's free tier may use data for product improvement; paid tier terms differ."),
            p("deepseek", .openAICompatible, "DeepSeek", "https://api.deepseek.com/v1", [
                ModelSpec(id: "deepseek-chat", displayName: "DeepSeek Chat", inputCentsPerMTok: 60, outputCentsPerMTok: 170, contextTokens: 128_000, maxOutputTokens: 8000),
            ], "Requests go to api.deepseek.com (servers in China) under DeepSeek's terms."),
            p("openrouter", .openAICompatible, "OpenRouter", "https://openrouter.ai/api/v1", [
                ModelSpec(id: "openai/gpt-5-mini", displayName: "GPT-5 mini via OpenRouter", inputCentsPerMTok: 30, outputCentsPerMTok: 250, contextTokens: 400_000, maxOutputTokens: 8000),
            ], "Requests go to openrouter.ai and are forwarded to the chosen model's provider."),
        ]
    }
}
