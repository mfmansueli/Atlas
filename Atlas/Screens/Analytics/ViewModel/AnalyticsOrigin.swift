//
//  AnalyticsOrigin.swift
//  Atlas
//

import Foundation

/// Where the person came from when a finding sent them to another
/// section: shown in a bar there, with Back to Analytics, which returns
/// to `tab`.
struct AnalyticsOrigin: Hashable, Sendable {
    var appID: StoreApp.ID
    /// The finding in a sentence.
    var text: String
    var tab: AnalyticsTab
    /// The section the finding opened (`WorkspaceNavigator.follow` sets
    /// it); nil shows the bar in any section but Analytics.
    var section: AppWorkspaceSection?

    /// Whether the bar shows on `section` of `appID`: the one the finding
    /// opened, never Analytics itself.
    func isShown(in section: AppWorkspaceSection, of appID: StoreApp.ID) -> Bool {
        guard appID == self.appID, section != .analytics else { return false }
        return self.section.map { $0 == section } ?? true
    }
}
