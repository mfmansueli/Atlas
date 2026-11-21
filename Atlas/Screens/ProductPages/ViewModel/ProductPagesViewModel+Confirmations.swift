//
//  ProductPagesViewModel+Confirmations.swift
//  Atlas
//

import Foundation

// Board 55: what Hide, Delete, Discard and moving a keyword say before
// they happen, and doing it once the person agrees.
extension ProductPagesViewModel {
    func confirmationTitle(_ confirmation: ProductPageConfirmation) -> String {
        switch confirmation {
        case let .hide(pageID): String(localized: "Hide “\(name(of: pageID))”?")
        case let .delete(pageID): String(localized: "Delete “\(name(of: pageID))”?")
        case let .discard(pageID):
            if discardCount(pageID) == 1 {
                String(localized: "Discard 1 change to “\(name(of: pageID))”?")
            } else {
                String(localized: "Discard \(discardCount(pageID)) changes to “\(name(of: pageID))”?")
            }
        case let .moveKeyword(keyword, _, _, _): String(localized: "Move “\(keyword)” to this page?")
        }
    }

    func confirmationMessage(_ confirmation: ProductPageConfirmation) -> String {
        switch confirmation {
        case .hide:
            return String(localized: """
            Its link keeps working and opens the default page. Searches for its keywords show the default page too. Turn \
            Visible back on at any time; that needs no review.
            """)
        case let .delete(pageID):
            if page(pageID)?.isDraft == true {
                return String(localized: "It’s only in Atlas, so nothing changes in App Store Connect. Its suggestions and changes go with it.")
            }
            return String(localized: """
            Its link stops leading here for good and opens the default page. Its keywords go back to the default page. The \
            page’s numbers stay in Analytics. This can’t be undone once it’s pushed.
            """)
        case let .discard(pageID):
            let undone = discardedParts(pageID)
            guard !undone.parts.isEmpty else { return String(localized: "The page goes back to what is in App Store Connect.") }
            let list = undone.parts.formatted(.list(type: .and))
            return undone.isSingular
                ? String(localized: "The page goes back to what is in App Store Connect: \(list) is undone.")
                : String(localized: "The page goes back to what is in App Store Connect: \(list) are undone.")
        case let .moveKeyword(_, _, _, fromName):
            return String(localized: "A keyword leads to one page. “\(fromName)” stops being shown for it once this page is approved and visible.")
        }
    }

    func confirmationButton(_ confirmation: ProductPageConfirmation) -> String {
        switch confirmation {
        case .hide: String(localized: "Hide Page")
        case .delete: String(localized: "Delete Page")
        case .discard: String(localized: "Discard Changes")
        case .moveKeyword: String(localized: "Move Keyword")
        }
    }

    func isDestructive(_ confirmation: ProductPageConfirmation) -> Bool {
        switch confirmation {
        case .delete, .discard: true
        case .hide, .moveKeyword: false
        }
    }

    /// The person agreed.
    func confirm(_ confirmation: ProductPageConfirmation) {
        self.confirmation = nil
        switch confirmation {
        case let .hide(pageID): hide(pageID)
        case let .delete(pageID): delete(pageID)
        case let .discard(pageID): discardChanges(of: pageID)
        case let .moveKeyword(keyword, locale, fromPageID, _): moveKeyword(keyword, locale: locale, from: fromPageID)
        }
    }

    // MARK: - Helpers

    private func name(of pageID: ProductPage.ID) -> String {
        page(pageID)?.name ?? ""
    }

    /// The changes Discard takes out: all but a draft's creation.
    private func discarded(_ pageID: ProductPage.ID) -> [PendingChange] {
        let builder = builder
        return builder.changes(of: pageID, in: queue.changes(for: app.id, section: .productPages)).filter { !builder.isNewPage($0) }
    }

    private func discardCount(_ pageID: ProductPage.ID) -> Int {
        discarded(pageID).count
    }

    /// What a change of `field` is called in the confirmation, once.
    private static func part(_ field: ProductPageField) -> String? {
        switch field {
        case .deepLink: String(localized: "the deep link")
        case .name: String(localized: "the name")
        case .visible: String(localized: "Visible")
        case .delete: String(localized: "deleting it")
        case .screenshots: String(localized: "its own screenshots")
        case .appPreviews: String(localized: "its own App Previews")
        case .promotionalText, .keywords: nil
        }
    }

    /// "1 promotional text", "2 keywords", "the deep link".
    private func discardedParts(_ pageID: ProductPage.ID) -> (parts: [String], isSingular: Bool) {
        let changes = discarded(pageID)
        var texts = 0
        var words = 0
        var others: [String] = []
        for change in changes {
            guard let last = change.id.split(separator: ".").last, let field = ProductPageField(rawValue: String(last)) else { continue }
            switch field {
            case .promotionalText: texts += 1
            case .keywords:
                let old = Set(ProductPageChangeBuilder.keywords(in: change.oldValue))
                let new = Set(ProductPageChangeBuilder.keywords(in: change.newValue))
                words += old.symmetricDifference(new).count
            default:
                if let part = Self.part(field), !others.contains(part) { others.append(part) }
            }
        }
        var parts: [String] = []
        if texts > 0 { parts.append(texts == 1 ? String(localized: "1 promotional text") : String(localized: "\(texts) promotional texts")) }
        if words > 0 { parts.append(words == 1 ? String(localized: "1 keyword") : String(localized: "\(words) keywords")) }
        parts += others
        return (parts, parts.count == 1 && texts <= 1 && words <= 1)
    }
}
