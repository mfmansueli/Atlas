//
//  AnalyticsDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state an Analytics DEBUG scene opens in: the view, the period, and
/// what's selected.
struct AnalyticsDebugLaunch {
    /// Taken by the section when it builds its view model.
    @MainActor static var pending: AnalyticsDebugLaunch?

    var tab = AnalyticsTab.funnel
    var days = 28
    var stage: FunnelStage?
    var dimension = BreakdownDimension.territory
    var selectedRow: String?
    var sort: BreakdownColumn?
    var findingsFilter = FindingsFilter.open
    /// A change's kind, to select it in After Changes.
    var change: ChangeKind?
    /// The Korean keywords change rather than the English subtitle.
    var picksLastChange = false
    var opensSettings = false
    var pane = SubscriptionsPane.summary
    var columnGroup = BreakdownColumnGroup.funnel
    var opensReports = false
    var settingsFocus: AnalyticsSettingsFocus?
    /// A finding's button pressed once the section is up: the section it
    /// opens, with the "From Analytics" bar saying `followText`.
    var follow: FindingAction?
    var followText = ""

    @MainActor
    func apply(to model: AnalyticsViewModel) {
        model.days = days
        if let stage { model.stage = stage }
        model.dimension = dimension
        model.selectedRowID = selectedRow
        if let sort { model.sort(by: sort) }
        model.findingsFilter = findingsFilter
        if let change {
            let matching = model.changes.filter { $0.kind == change }
            model.selectedChangeID = (picksLastChange ? matching.last : matching.first)?.id
        }
        model.subscriptionsPane = pane
        model.columnGroup = columnGroup
        model.tab = tab
        if opensSettings { model.openSettings(focus: settingsFocus) }
        if opensReports { model.isReportsPresented = true }
    }
}
#endif
