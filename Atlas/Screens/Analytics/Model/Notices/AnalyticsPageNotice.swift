//
//  AnalyticsPageNotice.swift
//  Atlas
//

import Foundation

/// The one notice above Analytics' content (README-DS §16, board 92): what
/// stops part of the numbers, or what's still on its way. One at a time,
/// the one that matters most first; the setup states take the whole page
/// instead.
enum AnalyticsPageNotice: Hashable, Sendable {
    /// The last check failed (Apple's error, already in Atlas's words).
    case failed(String)
    case missingVendorNumber
    case noSalesAccess
    /// One half of the data is still arriving.
    case partial(AnalyticsDataPart)
    /// Apple's newest data is `days` behind (the date at the top is amber).
    case stale(days: Int, newest: Date?, lastChecked: Date?)
    /// Apple is still making `count` of the newer reports.
    case preparingReports(count: Int, asked: Date?)

    struct Inputs: Hashable, Sendable {
        var availability: AnalyticsAvailability
        var activity: AnalyticsActivity = .idle
        var appName = ""
        var preparingReports = 0
        var reportsAsked: Date?
        /// The newest day of data, for the stale notice.
        var newest: Date?
        var lastChecked: Date?
    }

    /// The notice to show, or nil. A failed check comes first, then what
    /// `availability` says, then the newer reports still being made.
    static func choose(_ inputs: Inputs) -> AnalyticsPageNotice? {
        guard !inputs.availability.isBlocking else { return nil }
        if case let .failed(message) = inputs.activity { return .failed(message) }
        switch inputs.availability {
        case .missingVendorNumber: return .missingVendorNumber
        case .noSalesAccess: return .noSalesAccess
        case let .partial(part): return .partial(part)
        case let .stale(days): return .stale(days: days, newest: inputs.newest, lastChecked: inputs.lastChecked)
        case .notSetUp, .needsAdminKey, .waitingForApple, .downloading, .ready: break
        }
        return inputs.preparingReports > 0 ? .preparingReports(count: inputs.preparingReports, asked: inputs.reportsAsked) : nil
    }

    var bannerKind: BannerKind {
        switch self {
        case .failed, .missingVendorNumber, .noSalesAccess, .stale: .warning
        case .partial, .preparingReports: .info
        }
    }

    /// The bold first line.
    func title(appName: String) -> String {
        switch self {
        case let .failed(message):
            message
        case .missingVendorNumber:
            String(localized: "Trials, paid starts and proceeds need a vendor number.", comment: "kind:banner · Analytics")
        case .noSalesAccess:
            String(localized: "Your key’s role can’t read sales.", comment: "kind:banner · Analytics")
        case .partial(.sales):
            String(localized: "Sales are on their way.", comment: "kind:banner · Analytics")
        case .partial(.engagement):
            String(localized: "Impressions, page views and downloads are on their way.", comment: "kind:banner · Analytics")
        case let .stale(days, _, _):
            String(localized: "\(days) days behind (usually 1 to 2).", comment: "kind:banner · Analytics")
        case let .preparingReports(count, _):
            if count == 1 {
                String(localized: "Apple is preparing 1 more report for \(appName).", comment: "kind:banner · Analytics")
            } else {
                String(localized: "Apple is preparing \(count) more reports for \(appName).", comment: "kind:banner · Analytics")
            }
        }
    }

    /// The line after it.
    func message(now: Date) -> String? {
        switch self {
        case .failed:
            nil
        case .missingVendorNumber:
            String(localized: "Impressions, page views and downloads show without it.", comment: "kind:banner · Analytics")
        case .noSalesAccess:
            String(localized: "Admin, Finance and Sales keys can. Store-page numbers still show.", comment: "kind:banner · Analytics")
        case .partial(.sales):
            String(localized: "Impressions, page views and downloads arrived. Sales come in a separate report.", comment: "kind:banner · Analytics")
        case .partial(.engagement):
            String(localized: "Sales arrived. Impressions, page views and downloads come in Apple’s analytics reports.", comment: "kind:banner · Analytics")
        case let .stale(_, newest, lastChecked):
            Self.staleText(newest: newest, lastChecked: lastChecked, now: now)
        case let .preparingReports(_, asked):
            if let asked {
                String(
                    localized: "Asked \(AnalyticsText.day(asked)). The first usually take 1 to 2 days; Atlas checks daily.",
                    comment: "kind:banner · Analytics"
                )
            } else {
                String(localized: "The first usually take 1 to 2 days; Atlas checks daily.", comment: "kind:banner · Analytics")
            }
        }
    }

    var action: AnalyticsNoticeAction? {
        switch self {
        case .failed, .partial, .stale: .checkAgain
        case .missingVendorNumber: .addVendorNumber
        case .noSalesAccess: .fixSalesRole
        case .preparingReports: .showReports
        }
    }

    var identifier: String {
        switch self {
        case .failed: "analytics.notice.failed"
        case .missingVendorNumber: "analytics.notice.vendorNumber"
        case .noSalesAccess: "analytics.notice.salesRole"
        case let .partial(part): "analytics.notice.partial.\(part.rawValue)"
        case .stale: "analytics.stale"
        case .preparingReports: "analytics.preparingReports"
        }
    }

    /// "Newest data: Nov 9. Last checked today at 08:00."
    private static func staleText(newest: Date?, lastChecked: Date?, now: Date) -> String? {
        let parts = [
            newest.map { String(localized: "Newest data: \(AnalyticsText.day($0)).", comment: "kind:banner · Analytics") },
            lastChecked.map { String(localized: "Last checked \(AnalyticsText.moment($0, now: now)).", comment: "kind:banner · Analytics") },
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
