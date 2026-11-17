//
//  AppWorkspaceSectionGroup.swift
//  Atlas
//

import Foundation

/// The sidebar's groups of sections, by what the person is doing: the
/// summary, everything people see on the App Store (Pricing included), and
/// what happens once the version is out.
enum AppWorkspaceSectionGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case storeListing
    case afterRelease

    var id: String { rawValue }

    /// The group's heading; Overview stands alone, without one.
    var title: String? {
        switch self {
        case .overview: nil
        case .storeListing: String(localized: "Store Listing")
        case .afterRelease: String(localized: "After Release")
        }
    }

    /// The group's sections, in the sidebar's order.
    var sections: [AppWorkspaceSection] {
        AppWorkspaceSection.allCases.filter { $0.group == self }
    }
}
