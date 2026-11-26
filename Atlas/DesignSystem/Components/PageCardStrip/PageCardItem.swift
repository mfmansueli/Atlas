//
//  PageCardItem.swift
//  Atlas
//

import Foundation

/// One card in a `PageCardStrip`: an App Information page or an
/// Analytics view.
struct PageCardItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let systemImage: String
    /// "3 suggested", "Ready"; nil shows the name alone.
    var status: String?
    var tone: PageCardTone = .neutral
    /// A label drawn before this card, as a separator: "Only Apple sees".
    var groupTitle: String?
    /// The status while it loads: a grey skeleton line.
    var isLoading = false
    /// The accessibility identifier's last part.
    var identifier: String?
}
