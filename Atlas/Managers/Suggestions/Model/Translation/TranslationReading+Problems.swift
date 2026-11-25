//
//  TranslationReading+Problems.swift
//  Atlas
//

import Foundation

// What refuses an assistant's translation fields, the way every card text
// is checked (README-DS §9): a reason the assistant can act on. The
// natural version's field limit and App Review's rules are each tool's,
// which knows the field (`problems(natural:…)` there).
extension TranslationReading {
    /// One refused field, as `MCPToolError.invalidArgument` words it.
    struct Problem: Hashable, Sendable {
        var field: String
        var expected: String
    }

    /// Empty when the fields can show on a card.
    func problems() -> [Problem] {
        var problems: [Problem] = []
        for (index, note) in notes.enumerated() {
            let count = note.why.count
            if count > AssistantTextLimits.why {
                problems.append(Problem(
                    field: "notes[\(index)].why",
                    expected: String(localized: "one sentence of at most \(AssistantTextLimits.why) characters, not \(count)", comment: "kind:error")
                ))
            }
        }
        if let naturalMeans, naturalMeans.count > AssistantTextLimits.means {
            problems.append(Problem(
                field: "naturalMeans",
                expected: String(localized: "at most \(AssistantTextLimits.means) characters, not \(naturalMeans.count)", comment: "kind:error")
            ))
        }
        if naturalMeans != nil, natural == nil {
            problems.append(Problem(field: "naturalMeans", expected: String(localized: "sent with natural, the text it means", comment: "kind:error")))
        }
        return problems
    }

    /// Why `natural` can't go on a card for a text whose own checks are
    /// `check` (the field's limit, App Review's rules): the first reason it
    /// gives, said about natural, or nil.
    func naturalRefusal(_ check: (String) -> String?) -> String? {
        guard let natural, let reason = check(natural) else { return nil }
        return String(localized: "natural: \(reason)", comment: "kind:error")
    }
}
