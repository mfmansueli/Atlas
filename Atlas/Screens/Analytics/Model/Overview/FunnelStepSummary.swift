//
//  FunnelStepSummary.swift
//  Atlas
//

import Foundation

/// One step card of the Overview's funnel "From impression to paid" (board
/// 92): the count, one sentence in words ("5.4% of impressions opened the
/// page"), and the verdict against the previous period with its points
/// and, in the tooltip, how sure it is.
struct FunnelStepSummary: Hashable, Sendable, Identifiable {
    var stage: FunnelStage
    var count: String
    /// "5.4% of impressions opened the page", "+7% vs before", or why the
    /// step has no number; nil when the step before has none.
    var sentence: String?
    /// The sentence says why the number is missing (amber).
    var isGap = false
    var verdict: FunnelVerdict?
    /// "−0.4 pt" beside the verdict.
    var points: String?
    /// The words when there's no verdict: "Too few to tell", "No earlier
    /// period yet".
    var plainWord: String?
    var howSure: HowSure?

    var id: FunnelStage { stage }
    var title: String { stage.title }

    static func make(_ step: FunnelStep, isNew: Bool) -> FunnelStepSummary {
        var summary = FunnelStepSummary(stage: step.stage, count: step.countText)
        if let gap = step.gap {
            summary.sentence = gap.text
            summary.isGap = true
            return summary
        }
        guard step.stage.previous != nil else {
            summary.sentence = step.change.map { String(localized: "\($0) vs before", comment: "kind:label · a count against the previous period") }
            return summary
        }
        switch step.rate {
        case .missing:
            return summary
        case let .tooFew(count, total):
            summary.sentence = sentence(step.stage, count: count, total: total)
            summary.plainWord = ComparisonOutcome.tooFew.title
            return summary
        case let .measured(rate):
            summary.sentence = sentence(step.stage, share: AnalyticsText.percent(rate.value))
        }
        guard let comparison = step.comparison else {
            if isNew { summary.plainWord = String(localized: "No earlier period yet", comment: "kind:label · a new app's funnel step") }
            return summary
        }
        summary.verdict = FunnelVerdict(comparison.outcome)
        summary.howSure = howSure(comparison.outcome)
        if summary.verdict == nil { summary.plainWord = comparison.outcome.title }
        if summary.verdict != nil, !comparison.pointsText.isEmpty { summary.points = comparison.pointsText }
        return summary
    }

    /// "5.4% of impressions opened the page".
    static func sentence(_ stage: FunnelStage, share: String) -> String? {
        switch stage {
        case .impressions: nil
        case .pageViews: String(localized: "\(share) of impressions opened the page", comment: "kind:label · Analytics funnel step")
        case .downloads: String(localized: "\(share) of page views downloaded", comment: "kind:label · Analytics funnel step")
        case .trials: String(localized: "\(share) of downloads started a trial", comment: "kind:label · Analytics funnel step")
        case .paid: String(localized: "\(share) of trials paid", comment: "kind:label · Analytics funnel step")
        }
    }

    /// Too few for a rate: the counts, "12 of 40 impressions opened the
    /// page".
    static func sentence(_ stage: FunnelStage, count: Int, total: Int) -> String? {
        let (count, total) = (AnalyticsText.count(count), AnalyticsText.count(total))
        return switch stage {
        case .impressions: nil
        case .pageViews: String(localized: "\(count) of \(total) impressions opened the page", comment: "kind:label · funnel step, too few for a rate")
        case .downloads: String(localized: "\(count) of \(total) page views downloaded", comment: "kind:label · funnel step, too few for a rate")
        case .trials: String(localized: "\(count) of \(total) downloads started a trial", comment: "kind:label · funnel step, too few for a rate")
        case .paid: String(localized: "\(count) of \(total) trials paid", comment: "kind:label · funnel step, too few for a rate")
        }
    }

    /// The fixed words (README-DS §9): a difference that could be chance
    /// is Not very sure.
    static func howSure(_ outcome: ComparisonOutcome) -> HowSure? {
        switch outcome {
        case .tooFew: nil
        case .same: .notVerySure
        case let .higher(confidence), let .lower(confidence): confidence == .sure ? .sure : .fairlySure
        }
    }

    /// The tooltip: what the count means, then how sure.
    var tooltip: String {
        guard let howSure else { return stage.hint }
        return stage.hint + "\n" + String(localized: "How sure: \(howSure.word)", comment: "kind:tooltip · Analytics funnel step")
    }

    /// "Product page views: 9,870. 5.4% of impressions opened the page.
    /// Worse, −0.4 pt, Sure."
    var accessibilityText: String {
        var parts = ["\(title): \(count)"]
        if let sentence { parts.append(sentence) }
        if let verdict {
            parts.append([verdict.title, points, howSure?.word].compactMap(\.self).joined(separator: ", "))
        } else if let plainWord {
            parts.append(plainWord)
        }
        return parts.joined(separator: ". ")
    }
}
