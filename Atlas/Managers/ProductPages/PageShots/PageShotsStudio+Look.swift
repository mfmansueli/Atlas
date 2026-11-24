//
//  PageShotsStudio+Look.swift
//  Atlas
//

import Foundation

/// The Look of a page's set (board 52): the default page's template,
/// another starter, or a new look from Claude Design, which adds a stop
/// where the person chooses between three.
extension PageShotsStudio {
    /// The person chose the Look at Plan. Choosing a new look keeps the
    /// looks drawn before.
    func choose(look: PageShotsLook, for key: PageShotsRun.Key) {
        update(key) { run in
            var design = run.design ?? PageShotsDesign(look: look)
            design.look = look
            if !look.isClaudeDesign { design.problem = nil }
            run.design = look == .same && design.candidates.isEmpty ? nil : design
        }
    }

    /// The person chose one of the three looks.
    func pick(lookID: String, for key: PageShotsRun.Key) {
        update(key) { run in
            guard run.design?.candidates.contains(where: { $0.id == lookID }) == true else { return }
            run.design?.chosenID = lookID
        }
    }

    /// The assistant was asked for the three looks.
    func askedForLooks(_ key: PageShotsRun.Key, claudeRunID: UUID?) {
        update(key) { run in
            var design = run.design ?? PageShotsDesign(look: .claudeDesign)
            design.claudeRunID = claudeRunID
            design.askedAt = .now
            design.problem = nil
            run.design = design
        }
    }

    /// A look from propose_page_look: one with the same name takes the
    /// place of the one sent before, and the first one is chosen until the
    /// person chooses. Nil, with why, when there are three already.
    func receive(look candidate: PageShotsLookCandidate, for key: PageShotsRun.Key) -> String? {
        guard let run = runs[key] else { return nil }
        let candidates = run.design?.candidates ?? []
        let replaced = candidates.firstIndex { $0.name.caseInsensitiveCompare(candidate.name) == .orderedSame }
        if replaced == nil, candidates.count >= PageShotsDesign.candidateCount {
            let names = candidates.map { String(localized: "“\($0.name)”", comment: "kind:other") }.formatted(.list(type: .and))
            return String(localized: """
            \(PageShotsDesign.candidateCount) looks exist: \(names). To change one, resend it with the same name.
            """)
        }
        update(key) { run in
            var design = run.design ?? PageShotsDesign(look: .claudeDesign)
            if let replaced {
                let wasChosen = design.chosenID == design.candidates[replaced].id
                design.candidates[replaced] = candidate
                if wasChosen { design.chosenID = candidate.id }
            } else {
                design.candidates.append(candidate)
            }
            if design.chosenID == nil { design.chosenID = design.candidates.first?.id }
            design.problem = nil
            run.design = design
        }
        return nil
    }

    /// A looks session ended: without a look, it says so calmly.
    func lookSessionEnded(_ session: ClaudeCodeRun) -> Bool {
        guard let run = runs.values.first(where: { $0.appID == session.appID && $0.design?.claudeRunID == session.id }) else { return false }
        update(run.key) { run in
            run.design?.claudeRunID = nil
            if run.design?.candidates.isEmpty == true {
                let assistant = run.plan?.source ?? MCPClientKind.claudeCode.title
                run.design?.problem = String(localized: "\(assistant) stopped before sending a look. Ask again, or choose a template.")
            }
        }
        return true
    }
}
