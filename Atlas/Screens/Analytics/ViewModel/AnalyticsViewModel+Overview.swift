//
//  AnalyticsViewModel+Overview.swift
//  Atlas
//

import Foundation

/// What Analytics → Overview and the card strip show (board 92), from what
/// the view model already computed.
extension AnalyticsViewModel {
    // MARK: - Strip

    var tabSummaryInputs: AnalyticsTabSummary.Inputs {
        AnalyticsTabSummary.Inputs(
            funnel: funnel,
            stability: stability,
            newFindings: findings.newCount,
            openFindings: openFindings.count,
            pushes: changes.count,
            betterPushes: results.values.count { $0.state == .final && $0.main.comparison.outcome.isHigher },
            activeSubscribers: subscriptions?.active
        )
    }

    /// The card's line in the strip; a view without data says its case.
    func summary(for tab: AnalyticsTab) -> AnalyticsTabSummary {
        AnalyticsTabSummary.make(tab, availability: availability(for: tab), inputs: tabSummaryInputs)
    }

    // MARK: - Numbers

    /// The four numbers at the top of the Overview.
    func kpis(rating: OverviewRating?, isRatingLoading: Bool) -> [AnalyticsKPI] {
        AnalyticsKPI.make(AnalyticsKPI.Inputs(
            rating: rating,
            isRatingLoading: isRatingLoading,
            funnel: funnel,
            sellsSubscriptions: sellsSubscriptions,
            salesGap: sellsSubscriptions ? FunnelReport.gap(for: .paid, in: dataset) : nil,
            subscriptions: subscriptions,
            subscriptionsAvailability: availability(for: .subscriptions),
            stability: stability,
            stabilityAvailability: availability(for: .stability),
            hasStabilityTab: tabs.contains(.stability)
        ))
    }

    /// Follows a number's blue line inside Analytics; false for Rating,
    /// which leaves for Ratings & Reviews.
    @discardableResult
    func open(_ kpi: AnalyticsKPI.Kind) -> Bool {
        switch kpi {
        case .rating:
            return false
        case .proceeds:
            showProceedsByCountry()
        case .subscribers:
            guard tabs.contains(.subscriptions) else { return false }
            show(.summary)
        case .crashes:
            guard tabs.contains(.stability) else { return false }
            tab = .stability
        }
        return true
    }

    // MARK: - Funnel

    /// The five step cards of "From impression to paid".
    var funnelSteps: [FunnelStepSummary] {
        guard let funnel else { return [] }
        return funnel.steps.map { FunnelStepSummary.make($0, isNew: funnel.isNew) }
    }

    /// The line under the steps once both halves of the data are in; what
    /// is missing is the notice above the page instead.
    var funnelNote: String? {
        guard funnel != nil, sellsSubscriptions, dataset.salesState == .ready, dataset.engagementState == .ready else { return nil }
        return String(
            localized: "Paid starts: converted trials plus direct subscriptions. Trials from the last 7 days can’t have converted yet.",
            comment: "kind:footnote · Analytics Overview, under the funnel"
        )
    }

    /// The step a card click charts: a step whose number is missing opens
    /// what fixes it instead.
    func select(_ step: FunnelStepSummary) {
        if let gap = funnel?.step(step.stage)?.gap, gap.actionTitle != nil {
            openSettings(focus: gap == .needsVendorNumber ? .vendorNumber : .salesRole)
        } else {
            stage = step.stage
        }
    }

    // MARK: - Last push

    var lastPush: LastPushSummary? {
        LastPushSummary.make(changes: changes, results: results)
    }

    // MARK: - Notice

    /// The one notice above the content.
    var notice: AnalyticsPageNotice? {
        AnalyticsPageNotice.choose(AnalyticsPageNotice.Inputs(
            availability: availability,
            activity: activity,
            appName: app.name,
            preparingReports: preparingReports.count,
            reportsAsked: reports.firstChecked,
            newest: dataset.through?.date,
            lastChecked: lastChecked
        ))
    }

    /// The notice's button.
    func handle(_ action: AnalyticsNoticeAction) async {
        switch action {
        case .checkAgain: await refresh(force: true)
        case .addVendorNumber: openSettings(focus: .vendorNumber)
        case .fixSalesRole: openSettings(focus: .salesRole)
        case .showReports: isReportsPresented = true
        }
    }
}
