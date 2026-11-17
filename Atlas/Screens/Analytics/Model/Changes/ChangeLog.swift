//
//  ChangeLog.swift
//  Atlas
//

import Foundation

/// Reads Atlas's push history as the changes Analytics measures:
/// one per push and kind, newest first.
enum ChangeLog {
    private static let searchFields: Set<String> = ["name", "subtitle", "keywords"]

    static func changes(for appID: StoreApp.ID, in records: [PushRecord]) -> [MeasuredChange] {
        records.filter { $0.appID == appID }.flatMap(changes(in:)).sorted { $0.date > $1.date }
    }

    static func changes(in record: PushRecord) -> [MeasuredChange] {
        var result: [MeasuredChange] = []
        if let screenshots = record.screenshots, screenshots.pushedCount > 0, !screenshots.isRestore {
            result.append(MeasuredChange(
                id: "\(record.id.uuidString).screenshots", date: record.date, kind: .screenshots,
                title: title(String(localized: "New screenshots"), locales: screenshots.locales), localeCodes: screenshots.locales
            ))
        }
        let byKind = Dictionary(grouping: record.pushed.compactMap { change in kind(of: change).map { ($0, change) } }, by: \.0)
        for kind in [ChangeKind.searchText, .pageText, .prices, .inAppTexts] {
            guard let changes = byKind[kind]?.map(\.1), !changes.isEmpty else { continue }
            let locales = orderedUnique(changes.compactMap(localeCode(of:)))
            var change = MeasuredChange(
                id: "\(record.id.uuidString).\(kind.rawValue)", date: record.date, kind: kind,
                title: title(for: kind, changes: changes, locales: locales), localeCodes: locales
            )
            if changes.count == 1, kind != .prices {
                change.oldValue = changes[0].oldValue
                change.newValue = changes[0].newValue
            }
            result.append(change)
        }
        return result
    }

    /// nil for changes Analytics doesn't measure (App Information,
    /// retention messages, restores of the same).
    static func kind(of change: PendingChange) -> ChangeKind? {
        switch change.section {
        case .subscriptionPricing:
            return change.id.lowercased().hasPrefix("retention") ? nil : .prices
        case .storePage:
            guard change.id.hasPrefix("storePage."), !change.id.contains(".inApp.") else { return .inAppTexts }
            let field = change.id.split(separator: ".").last.map(String.init) ?? ""
            return searchFields.contains(field) ? .searchText : .pageText
        default:
            return nil
        }
    }

    /// The listing change's locale, from "storePage.<app>.version.<id>.de-DE.subtitle".
    static func localeCode(of change: PendingChange) -> String? {
        let parts = change.id.split(separator: ".").map(String.init)
        guard change.id.hasPrefix("storePage."), !change.id.contains(".inApp."), parts.count >= 2 else { return nil }
        let code = parts[parts.count - 2]
        return StoreLocaleCatalog.locale(code: code) == nil ? nil : code
    }

    private static func title(for kind: ChangeKind, changes: [PendingChange], locales: [String]) -> String {
        switch kind {
        case .prices:
            let regions = Set(changes.compactMap(\.flagRegion)).count
            return regions > 1 ? String(localized: "Prices · \(regions) countries") : String(localized: "Prices")
        case .inAppTexts:
            return String(localized: "Paywall text · \(changes.count) texts")
        case .searchText, .pageText:
            let fields = orderedUnique(changes.compactMap { $0.title.components(separatedBy: " · ").last })
            let what = fields.count == 1 ? String(localized: "New \(fields[0].localizedLowercase)") : String(localized: "\(fields.count) store page texts")
            return title(what, locales: locales)
        case .screenshots:
            return title(String(localized: "New screenshots"), locales: locales)
        }
    }

    private static func title(_ what: String, locales: [String]) -> String {
        switch locales.count {
        case 0: what
        case 1: "\(what) · \(StoreLocaleCatalog.locale(code: locales[0])?.name ?? locales[0])"
        default: String(localized: "\(what) · \(locales.count) languages")
        }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
