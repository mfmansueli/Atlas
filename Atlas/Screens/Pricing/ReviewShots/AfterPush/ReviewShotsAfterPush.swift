//
//  ReviewShotsAfterPush.swift
//  Atlas
//

import Foundation

/// What Pricing says about review screenshots once a push uploaded them
/// (README — Pricing: review screenshots, “Uploaded”): since when each is in
/// App Store Connect, from the push history, and the toast after the push
/// with each product's state as Atlas read it again.
enum ReviewShotsAfterPush {
    /// When the push that uploaded `changeID` ended; nil when no push of
    /// this Mac did (it was there before, or added elsewhere).
    static func uploadedAt(_ changeID: PendingChange.ID, in records: [PushRecord]) -> Date? {
        records.filter { $0.pushed.contains { $0.id == changeID } }.map(\.date).max()
    }

    /// The file the last push of `changeID` uploaded, while this Mac still
    /// keeps it: the uploaded card's thumbnail.
    static func uploadedFile(_ changeID: PendingChange.ID, in records: [PushRecord]) -> URL? {
        let record = records.filter { $0.pushed.contains { $0.id == changeID } }.max { $0.date < $1.date }
        guard let change = record?.pushed.first(where: { $0.id == changeID }),
              let path = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change)?.path,
              FileManager.default.fileExists(atPath: path)
        else { return nil }
        return URL(filePath: path)
    }

    /// “In App Store Connect since today. Apple lets you replace it, not
    /// remove it.”: today, yesterday or the day; without the day when no
    /// push of this Mac uploaded it.
    static func sinceLine(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date else { return String(localized: "In App Store Connect. Apple lets you replace it, not remove it.") }
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "In App Store Connect since today. Apple lets you replace it, not remove it.", comment: "kind:description")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "In App Store Connect since yesterday. Apple lets you replace it, not remove it.", comment: "kind:description")
        }
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "In App Store Connect since \(day). Apple lets you replace it, not remove it.", comment: "kind:description")
    }

    /// The review screenshot changes of `appID` that `records` pushed.
    static func pushedChangeIDs(in records: [PushRecord], appID: StoreApp.ID) -> Set<PendingChange.ID> {
        Set(records.flatMap(\.pushed).filter { $0.appID == appID && PurchaseReviewScreenshotChangeBuilder.owns($0) }.map(\.id))
    }

    /// The toast once the products were read again: “Uploaded. Atlas read
    /// each product again from App Store Connect: 3 products are Ready to
    /// Submit.” `states` are the products' states in words, in order;
    /// `name` the product's when there's one.
    static func toast(states: [String], name: String?) -> String {
        if states.count == 1, let state = states.first, let name {
            return String(localized: "Uploaded. Atlas read \(name) again from App Store Connect: it’s \(state).", comment: "kind:toast")
        }
        var counts: [(state: String, count: Int)] = []
        for state in states {
            if let index = counts.firstIndex(where: { $0.state == state }) {
                counts[index].count += 1
            } else {
                counts.append((state, 1))
            }
        }
        if counts.count == 1, let only = counts.first {
            return String(
                localized: "Uploaded. Atlas read each product again from App Store Connect: \(only.count) products are \(only.state).",
                comment: "kind:toast"
            )
        }
        let parts = counts.map { part in
            part.count == 1 ? String(localized: "1 is \(part.state)", comment: "kind:toast") : String(localized: "\(part.count) are \(part.state)", comment: "kind:toast")
        }
        return String(
            localized: "Uploaded. Atlas read each product again from App Store Connect: \(ListFormatter.localizedString(byJoining: parts)).",
            comment: "kind:toast"
        )
    }
}
