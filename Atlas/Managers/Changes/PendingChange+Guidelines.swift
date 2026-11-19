//
//  PendingChange+Guidelines.swift
//  Atlas
//

import Foundation

extension PendingChange {
    /// What App Review would reject in the text this change pushes (Store
    /// Page, In-App Event texts, retention messages), which Review & Push
    /// warns about; empty for other changes.
    /// The field is the id's last part: `storePage.<app>.version.<id>.<locale>.<field>`.
    /// In-app texts (`storePage.<app>.inApp.…`) end in `name` and
    /// `description` too, but follow their own rules: an in-app purchase
    /// named "7-day Trial" isn't the app's name.
    var guidelineIssues: [StoreTextGuidelineIssue] {
        if section == .inAppEvents { return eventTextIssues }
        if section == .productPages { return productPageTextIssues }
        if id.hasPrefix(RetentionChangeBuilder.messagePrefix) { return retentionMessageIssues }
        guard section == .storePage else { return [] }
        if id.contains(".inApp.") {
            return inAppTextField.map { StoreTextGuidelineCheck.issues(in: newValue, for: $0) } ?? []
        }
        guard let name = id.split(separator: ".").last, let field = ListingField(rawValue: String(name)) else { return [] }
        return StoreTextGuidelineCheck.issues(in: newValue, for: field)
    }

    /// An event's texts: one text (`inAppEvents.<app>.<event>.<locale>.<field>`),
    /// a new language's (`….<locale>.new`, the texts one per line), or a new
    /// event's, which are its `event.<locale>.<field>` parts. Artwork and
    /// other changes have none.
    private var eventTextIssues: [StoreTextGuidelineIssue] {
        let last = id.split(separator: ".").last.map(String.init) ?? ""
        if InAppEventField(rawValue: last) != nil || last == InAppEventChangeBuilder.newSuffix {
            return StoreTextGuidelineCheck.issues(in: newValue, for: .eventText)
        }
        let fieldNames = Set(InAppEventField.allCases.map(\.rawValue))
        let texts = (creation?.fields ?? []).filter { part in
            part.id.hasPrefix("event.") && fieldNames.contains(part.id.split(separator: ".").last.map(String.init) ?? "")
        }
        return StoreTextGuidelineCheck.issues(in: texts.map(\.newValue).joined(separator: "\n"), for: .eventText)
    }

    /// A page's promotional text (`productPages.<app>.<page>.<locale>.promotionalText`),
    /// or a new page's, which are its `page.<locale>.promotionalText` parts.
    private var productPageTextIssues: [StoreTextGuidelineIssue] {
        let field = ProductPageField.promotionalText.rawValue
        if id.hasSuffix(".\(field)") { return StoreTextGuidelineCheck.issues(in: newValue, for: ListingField.promotionalText) }
        let texts = (creation?.fields ?? []).filter { $0.id.hasSuffix(".\(field)") }
        return StoreTextGuidelineCheck.issues(in: texts.map(\.newValue).joined(separator: "\n"), for: ListingField.promotionalText)
    }

    /// A retention message's headers and bodies, its `header.<locale>` and
    /// `body.<locale>` parts.
    private var retentionMessageIssues: [StoreTextGuidelineIssue] {
        let texts = (creation?.fields ?? []).filter { $0.id.hasPrefix("header.") || $0.id.hasPrefix("body.") }
        return StoreTextGuidelineCheck.issues(in: texts.map(\.newValue).joined(separator: "\n"), for: .retentionMessage)
    }

    /// The in-app text this change writes, from its request's path
    /// (`/v1/subscriptionGroupLocalizations/…`, `/v2/inAppPurchaseLocalizations`):
    /// the id names its owner by resource id only. A new localization
    /// carries the name and description together; both follow the same
    /// rules, so it counts as the name.
    private var inAppTextField: InAppTextField? {
        let path = requests.first?.path ?? ""
        let isDescription = id.hasSuffix(".description")
        if path.contains("subscriptionGroupLocalizations") { return .subscriptionGroupName }
        if path.contains("subscriptionLocalizations") { return isDescription ? .subscriptionDescription : .subscriptionName }
        if path.contains("inAppPurchaseLocalizations") { return isDescription ? .purchaseDescription : .purchaseName }
        return nil
    }
}
