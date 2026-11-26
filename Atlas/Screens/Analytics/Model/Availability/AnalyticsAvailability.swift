//
//  AnalyticsAvailability.swift
//  Atlas
//

import Foundation

/// What Analytics can show for one app, as a whole (README-DS §16, board
/// 92). The first four take the whole page (no card strip, no findings
/// badge in the sidebar, the Autopilot bar offers only “Ask What
/// Analytics Shows…”); the next four are a notice above the content, one
/// at a time; `ready` is everything in place.
enum AnalyticsAvailability: Hashable, Sendable {
    /// Nobody asked Apple for this app's reports: "Ask Apple for Reports".
    case notSetUp
    /// The key isn't Admin, so it can't ask; the page says how to get one.
    case needsAdminKey
    /// Asked on `asked`; Apple's first reports take 1 to 2 days.
    case waitingForApple(asked: Date?)
    /// Downloading Apple's reports; `finished` of the steps are done
    /// (grey skeleton on the cards).
    case downloading(finished: Int)
    /// Sales and Trends needs the vendor number.
    case missingVendorNumber
    /// The key's role can't read sales.
    case noSalesAccess
    /// One half of the data is still arriving.
    case partial(AnalyticsDataPart)
    /// Apple's reports are `days` behind (the date at the top turns amber).
    case stale(days: Int)
    /// Everything is in: data since `since`, `days` days of it.
    case ready(since: Date?, days: Int)

    /// An app with fewer days than this says "Since Nov 1 · 9 days of data".
    static let newAppDays = 28

    /// What the store and the dataset say, which the state is worked out
    /// from.
    struct Inputs: Hashable, Sendable {
        var setup: AnalyticsSetup
        var activity: AnalyticsActivity = .idle
        /// The funnel has numbers to show.
        var hasData: Bool
        var askedOn: Date?
        var sellsSubscriptions = true
        var salesState: SalesState = .ready
        var engagementState: EngagementState = .ready
        var staleDays: Int?
        var firstDay: Date?
        var dayCount = 0
    }

    /// Works out the state from what the store and the dataset say.
    static func make(_ inputs: Inputs) -> AnalyticsAvailability {
        let (setup, activity, hasData, askedOn) = (inputs.setup, inputs.activity, inputs.hasData, inputs.askedOn)
        let (sellsSubscriptions, salesState, engagementState) = (inputs.sellsSubscriptions, inputs.salesState, inputs.engagementState)
        let (staleDays, firstDay, dayCount) = (inputs.staleDays, inputs.firstDay, inputs.dayCount)
        switch setup {
        case .off:
            return .notSetUp
        case .keyCannotAsk:
            return .needsAdminKey
        case let .waiting(asked):
            if case let .loading(finished) = activity { return .downloading(finished: finished) }
            return .waitingForApple(asked: asked)
        case .ready:
            break
        }
        guard hasData else {
            if case let .loading(finished) = activity { return .downloading(finished: finished) }
            return .waitingForApple(asked: askedOn)
        }
        if sellsSubscriptions {
            switch salesState {
            case .needsVendorNumber: return .missingVendorNumber
            case .keyCannotRead: return .noSalesAccess
            case .waiting, .ready: break
            }
        }
        if case .waiting = engagementState { return .partial(.engagement) }
        if sellsSubscriptions, salesState == .waiting { return .partial(.sales) }
        if let staleDays { return .stale(days: staleDays) }
        return .ready(since: firstDay, days: dayCount)
    }

    /// Takes the whole page: no strip, no data views.
    var isBlocking: Bool {
        switch self {
        case .notSetUp, .needsAdminKey, .waitingForApple, .downloading: true
        case .missingVendorNumber, .noSalesAccess, .partial, .stale, .ready: false
        }
    }

    /// The card strip shows only when there is data.
    var showsStrip: Bool { !isBlocking }

    /// The sidebar shows Analytics' findings badge only once there is data.
    var showsFindingsBadge: Bool { !isBlocking }

    /// Before the first reports the Autopilot bar offers only “Ask What
    /// Analytics Shows…”.
    var offersOnlyAsk: Bool { isBlocking }

    /// A notice above the content, one at a time.
    var isNotice: Bool {
        switch self {
        case .missingVendorNumber, .noSalesAccess, .partial, .stale: true
        default: false
        }
    }

    /// Fewer days than a full period: counts carry more than rates.
    var isNewApp: Bool {
        if case let .ready(_, days) = self { return days < Self.newAppDays }
        return false
    }

    /// The toolbar's status line for the states that replace the numbers,
    /// and for a new app; nil when the line says the usual.
    var toolbarText: String? {
        switch self {
        case .notSetUp: String(localized: "Not set up", comment: "kind:status · Analytics toolbar line")
        case .needsAdminKey: String(localized: "Needs an Admin key", comment: "kind:status · Analytics toolbar line")
        case .waitingForApple: String(localized: "Waiting for Apple’s first reports", comment: "kind:status · Analytics toolbar line")
        case .downloading: String(localized: "Downloading Apple’s reports", comment: "kind:status · Analytics toolbar line")
        case let .ready(since?, days) where days < Self.newAppDays:
            String(localized: "Since \(AnalyticsText.day(since)) · \(days) days of data", comment: "kind:status · Analytics toolbar line, a new app")
        case .missingVendorNumber, .noSalesAccess, .partial, .stale, .ready: nil
        }
    }
}
