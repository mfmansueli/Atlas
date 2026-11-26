//
//  ChangeStatus.swift
//  Atlas
//

import Foundation

/// Where a push's result stands in After Changes (board 92): better (or
/// worse, or about the same) after 28 days, still waiting for data, too few
/// to tell, or a price change, whose result is in Pricing → Results.
enum ChangeStatus: Hashable, Sendable {
    case better
    case worse
    case same
    /// 28 days have passed and the counts are too small to tell from chance.
    case tooFew
    /// Day `day` of 28: an early read.
    case waiting(day: Int)
    /// Apple's data doesn't reach back before the push.
    case noBefore
    /// Prices are measured per territory in Pricing → Results.
    case pricing
    /// Apple's reports miss the change's dates or its step.
    case noData

    static func make(_ change: MeasuredChange, result: ChangeResult?) -> ChangeStatus {
        if change.kind == .prices { return .pricing }
        guard let result else { return .noData }
        switch result.state {
        case let .measuring(day, _): return .waiting(day: day)
        case .noBefore: return .noBefore
        case .final:
            switch result.main.comparison.outcome {
            case .tooFew: return .tooFew
            case .same: return .same
            case .higher: return .better
            case .lower: return .worse
            }
        }
    }

    /// The pill in the list: "Better", "Day 12 of 28"…
    var title: String {
        switch self {
        case .better: String(localized: "Better", comment: "kind:pill · After Changes")
        case .worse: String(localized: "Worse", comment: "kind:pill · After Changes")
        case .same: String(localized: "About the same", comment: "kind:pill · After Changes")
        case .tooFew: String(localized: "Too few to tell", comment: "kind:pill · After Changes")
        case let .waiting(day): String(localized: "Day \(day) of \(ResultsEvaluator.windowDays)", comment: "kind:pill · After Changes")
        case .noBefore: String(localized: "No data before it", comment: "kind:pill · After Changes")
        case .pricing: String(localized: "In Pricing → Results", comment: "kind:pill · After Changes")
        case .noData: String(localized: "No data", comment: "kind:pill · After Changes")
        }
    }

    /// Worse is a state worth noticing (amber); a final verdict is neutral;
    /// the rest are still open, outlined.
    var pillStyle: PillStyle {
        switch self {
        case .worse: .warning
        case .better, .same: .neutral
        case .tooFew, .waiting, .noBefore, .pricing, .noData: .outline
        }
    }

    /// Whether the detail shows the step's numbers and chart.
    var hasNumbers: Bool {
        switch self {
        case .pricing, .noData: false
        default: true
        }
    }
}
