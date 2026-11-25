//
//  MCPNaturalCheck.swift
//  Atlas
//

import Foundation

/// A translation's `natural` version (board 77) is checked like the text it
/// can replace: the field's limit and App Review's metadata rules. Each
/// gives the reason, said about `natural`, or nil when it can go on the
/// card.
enum MCPNaturalCheck {
    static func refusal(_ layers: SuggestionLayers?, for field: ListingField) -> String? {
        layers?.translation?.naturalRefusal { text in
            problem(ListingFieldValidator.validate(text, for: field)) ?? guidelineProblem(StoreTextGuidelineCheck.issues(in: text, for: field))
        }
    }

    static func refusal(_ layers: SuggestionLayers?, for field: InAppTextField) -> String? {
        layers?.translation?.naturalRefusal { text in
            problem(ListingFieldValidator.validate(text, for: field)) ?? guidelineProblem(StoreTextGuidelineCheck.issues(in: text, for: field))
        }
    }

    /// The field's own checks, worded.
    private static func problem(_ validation: ListingFieldValidation) -> String? {
        switch validation {
        case .valid: nil
        case .empty: String(localized: "The text is empty.", comment: "kind:error")
        case .invalidURL: String(localized: "Not a full https:// URL.", comment: "kind:error")
        case let .overLimit(count, limit):
            String(localized: "Over the limit: \(count) of \(limit.maximum) \(limit.unit.name). Shorten it and send it again.", comment: "kind:error")
        }
    }

    private static func guidelineProblem(_ issues: [StoreTextGuidelineIssue]) -> String? {
        issues.isEmpty ? nil : String(localized: "\(issues.assistantReason) Rewrite it and send it again.", comment: "kind:error")
    }
}
