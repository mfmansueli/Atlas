//
//  AppWorkspaceSection+PageAction.swift
//  Atlas
//

import Foundation

/// The page action each section has in the toolbar (board 80). Store Page,
/// App Information, Reviews, Analytics and Overview create nothing: their
/// toolbar has only the title.
extension AppWorkspaceSection {
    var pageAction: WorkspacePageAction? {
        switch self {
        case .productPages:
            WorkspacePageAction(
                section: self, title: String(localized: "New Page…", comment: "kind:button"), systemImage: "plus",
                help: String(localized: "A custom product page for one audience", comment: "kind:tooltip"), identifier: "pages.new"
            )
        case .inAppEvents:
            WorkspacePageAction(
                section: self, title: String(localized: "New Event…", comment: "kind:button"), systemImage: "plus",
                help: String(localized: "An In-App Event, in every language", comment: "kind:tooltip"), identifier: "events.new"
            )
        case .nominations:
            WorkspacePageAction(
                section: self, title: String(localized: "New Nomination…", comment: "kind:button"), systemImage: "plus",
                help: String(localized: "Start a draft. Nothing is sent until you push.", comment: "kind:tooltip"), identifier: "nominations.new"
            )
        case .subscriptionPricing:
            WorkspacePageAction(
                section: self, title: String(localized: "Add Subscription…", comment: "kind:button"), systemImage: "plus",
                help: String(localized: "A new subscription, priced in every country", comment: "kind:tooltip"),
                identifier: "pricing.addSubscription"
            )
        case .screenshots:
            WorkspacePageAction(
                section: self, title: String(localized: "Add Screenshots…", comment: "kind:button"), systemImage: "plus",
                help: String(localized: "PNG or JPEG files, for this language and device", comment: "kind:tooltip"), identifier: "screenshots.add"
            )
        case .overview, .storePage, .appInformation, .reviews, .analytics:
            nil
        }
    }
}
