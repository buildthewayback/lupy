// LupyCore — demo content for screenshots, CI smoke tests and first-look exploration.
// Only used with the --demo launch option (and always in a separate data folder in CI).

extension LupyEngine {
    /// Seeds a realistic, clearly-labelled demo: an approved plan, a plan awaiting review, a handoff
    /// waiting to be pasted, an approval request and a preference. Idempotent.
    public func seedDemo() throws {
        guard !store.hasProcessed("demo-v1") else { return }
        guard let income = state.projects.values.first(where: { $0.name == "Urgent income & clients" }),
              let penglai = state.projects.values.first(where: { $0.name == "PENGLAI City" }),
              let arena = state.workers.values.first(where: { $0.name == "Arena" }) else {
            throw EngineError.invalid("Bootstrap must run before demo data.")
        }
        let g1 = try captureGoal("[Demo] Send the ACME logo invoice by Friday\n[Demo] Follow up with ACME next week", projectID: income.id)
        _ = try approvePlan(try planHeuristically(goalID: g1.id).id)
        let g2 = try captureGoal("[Demo] Write the PENGLAI City teaser script\n[Demo] Render the key art\n[Demo] Post the teaser on Instagram", projectID: penglai.id)
        _ = try planHeuristically(goalID: g2.id)
        let coding = try addTask(projectID: penglai.id, title: "[Demo] Add save-game system", kind: .coding, acceptance: ["PR with passing CI checks"])
        _ = try dispatch(try delegate(coding.id, to: arena.id).id)
        _ = try propose(makeAction(kind: .publishContent, title: "[Demo] Post the teaser on Instagram", target: "instagram:@penglai",
                                   projectID: penglai.id, originator: .lupy), consequence: "The post becomes public.")
        _ = try remember(scope: .global, kind: .preference, title: "[Demo] Deep work before noon", key: "work-hours")
        var s = state.settings
        s.onboardingComplete = true
        try updateSettings(s)
        try commit([ev(.system, "Demo data added", .note(text: "Demo data added", relatedID: nil))], key: "demo-v1")
    }
}
