//
//  RefreshPart.swift
//  Atlas
//

import Foundation

/// What a Refresh reads again before it's over (README-DS §15): the app
/// list, the version and its builds, and the section that shows. The
/// other sections read again when they're next opened (`refreshCount`
/// and `SectionLoadStamp`).
enum RefreshPart: Hashable, Sendable, CaseIterable {
    /// The sidebar's app list.
    case apps
    /// The selected app's version and builds (the sidebar's footer).
    case release
    /// The section that shows.
    case section
}
