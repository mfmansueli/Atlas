//
//  DebugReportsData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Apple's newer reports for the sample apps, as boards 59–62 show them:
/// Lumen with a month of retention, subscribers by page, a crashing 1.4
/// and deletions; Quiet Timer with too few people at the cancel screen;
/// Parcel Pal with the reports sent empty; Tempo still being prepared.
enum DebugReportsData {
    typealias Data = DebugAnalyticsData

    /// Newest day in the reports (Nov 9): retention is complete through Nov 5.
    static let last = Data.through

    // MARK: - Lumen

    static var lumen: ReportsArchive {
        var builder = Builder()
        retention(into: &builder)
        subscriptions(into: &builder)
        stability(into: &builder)
        afterDownload(into: &builder)
        builder.add(.subscriptionStates, day: last, values: ["Billing issue", "Billing retry", "Lumen Pro", "", "", "", "", "", ""], counts: [31])
        builder.add(.subscriptionStates, day: last, values: ["Billing issue", "Grace period", "Lumen Pro", "", "", "", "", "", ""], counts: [0])
        builder.add(.subscriptionStates, day: last, values: ["Paid plans", "Full price", "Lumen Pro", "", "", "", "", "", ""], counts: [1240])
        return builder.archive(firstChecked: Data.date(month: 11, day: 1))
    }

    static let lumenGracePeriod = GracePeriodSetting(id: "grace-lumen", isOn: false, duration: nil)

    /// Retention Messaging: 412 opened in the 28 days through Nov 5, 94 stayed.
    private static func retention(into builder: inout Builder) {
        let window = AnalyticsPeriod(ending: last.adding(-4), length: 28)
        let before = window.previous
        let arriving = AnalyticsPeriod(first: last.adding(-3), last: last)
        let messages = [
            Message("rm-before-you-go", "Before you go", "Text message with offer", "50% off 3 months", 190, 58, [41, 13, 4]),
            Message("rm-miss-you", "We’ll miss you", "Text message", "", 122, 26, [0, 17, 9]),
            Message("", "", "No Message", "", 100, 10, [0, 10, 0]),
        ]
        for message in messages {
            let (opened, stayed, saves) = (message.opened, message.stayed, message.saves)
            let subscriptions = ["Lumen Pro Monthly", "Lumen Pro Yearly"]
            for (index, subscription) in subscriptions.enumerated() {
                let share = index == 0 ? 0.7 : 0.3
                func row(_ event: String, _ saveType: String, _ total: Int, _ period: AnalyticsPeriod) {
                    for (day, count) in spread(Int((Double(total) * share).rounded()), over: period) where count > 0 {
                        builder.add(.retention, day: day, values: [
                            event, subscription, message.type, message.name, message.id, message.offer, "", saveType, "iPhone", "US",
                        ], counts: [count])
                    }
                }
                row("Page views", "", opened, window)
                row("Cancels", "", opened - stayed, window)
                row("Saves", "Redeem offer", saves[0], window)
                row("Saves", "Don’t cancel", saves[1], window)
                row("Saves", "Switch plan", saves[2], window)
                // The month before: a little lower.
                row("Page views", "", opened, before)
                row("Cancels", "", opened - stayed * 8 / 10, before)
                // Still arriving.
                row("Page views", "", opened / 7, arriving)
                row("Cancels", "", (opened - stayed) / 9, arriving)
            }
        }
    }

    /// A retention message's sample counts: saves by type are offer, don't
    /// cancel and switch plan.
    private struct Message {
        let id, name, type, offer: String
        let opened, stayed: Int
        let saves: [Int]

        init(_ id: String, _ name: String, _ type: String, _ offer: String, _ opened: Int, _ stayed: Int, _ saves: [Int]) {
            (self.id, self.name, self.type, self.offer) = (id, name, type, offer)
            (self.opened, self.stayed, self.saves) = (opened, stayed, saves)
        }
    }

    /// Subscription events for the 28 days through Nov 9.
    private static func subscriptions(into builder: inout Builder) {
        let window = AnalyticsPeriod(ending: last, length: 28)
        // grouping, subType, offerType, offerName, duration, planChange, cancelReason, page, count
        func event(
            _ grouping: String, _ subType: String, offerType: String = "", offer: String = "", duration: String = "", plan: String = "",
            reason: String = "", page: String = "", source: String = "App Store Search", campaign: String = "", _ total: Int,
            period: AnalyticsPeriod? = nil
        ) {
            let pageType = page.isEmpty ? "Product page" : "Product page"
            for (day, count) in spread(total, over: period ?? window) where count > 0 {
                builder.add(.subscriptionEvents, day: day, values: [
                    grouping, subType, "Lumen Pro Monthly", offerType, offer, duration, plan, reason, source, "", campaign, pageType, page, "iPhone", "US",
                ], counts: [count])
            }
        }
        // Trials and paid, by page.
        for (page, trials, converted, lapsed, campaign) in [
            ("", 380, 132, 190, ""), ("Mood tracking", 90, 14, 58, "spring-mood"), ("Sleep journal", 50, 24, 20, "podcast-sleep"),
        ] {
            event(
                "Offer Starts", "Free Trial Starts", offerType: "Free Trial", offer: "1 week free", duration: "1 Week", page: page, campaign: campaign,
                trials
            )
            event(
                "Paid Subscriptions from Offers", "Full Price from Free Trial", offerType: "Free Trial", offer: "1 week free", page: page,
                campaign: campaign, converted
            )
            event("Voluntary Churn", "Voluntary Churn from Free Trials", reason: "Turned off auto-renew", page: page, campaign: campaign, lapsed)
        }
        event("Paid Subscription Starts", "Full Price Subscription Starts", 64)
        event(
            "Offer Starts", "Offer Code Starts", offerType: "Offer Code", offer: "PODCAST30", duration: "1 Month", source: "Web Referrer",
            campaign: "podcast-sleep", 60
        )
        event("Paid Subscriptions from Offers", "Full Price from Paid Offer", offerType: "Offer Code", offer: "PODCAST30", campaign: "podcast-sleep", 4)
        event("Offer Starts", "Paid Offer Starts", offerType: "Win-back Offer", offer: "Come back 50%", duration: "1 Month", 45)
        event("Paid Subscriptions from Offers", "Full Price from Paid Offer", offerType: "Win-back Offer", offer: "Come back 50%", 18)
        event(
            "Offer Starts", "Paid Offer Starts", offerType: "Promotional Offer", offer: "Holiday 2026", duration: "2 Months", 30,
            period: AnalyticsPeriod(first: Data.through.adding(-2), last: last)
        )
        // Billing.
        event("Entered Billing Issue", "Entered Billing Retry from Paid", 83)
        event("Recoveries from Billing Issue", "Paid Recoveries from Billing Retry", 29)
        event("Involuntary Churn", "Involuntary Churn from Paid", reason: "Billing Issue", 54)
        event("Voluntary Churn", "Voluntary Churn from Paid", reason: "Turned off auto-renew", 120)
        event("Voluntary Churn", "Voluntary Churn from Paid", reason: "Price Increase", 8)
        // Plan changes.
        event("Exits", "Plan Changes", plan: "Upgrade", 22)
        event("Exits", "Plan Changes", plan: "Downgrade", 9)
        event("Exits", "Plan Changes", plan: "Crossgrade", 4)
    }

    /// 1.3 against 1.4, released Nov 1 in phases: 1.4 crashes about 3.2× as often.
    private static func stability(into builder: inout Builder) {
        let release = Data.date(month: 11, day: 1)
        for back in 0..<40 {
            let day = last.adding(-back)
            let onNew = day >= AnalyticsDay(release)
            let newShare = onNew ? min(0.6, Double(day.number - AnalyticsDay(release).number + 1) * 0.07) : 0
            for (device, deviceShare, newRate, oldRate) in [("iPhone", 0.85, 3.6, 1.3), ("iPad", 0.15, 8.4, 1.4)] {
                let sessions = 3400.0 * deviceShare
                let old = Int(sessions * (1 - newShare))
                let new = Int(sessions * newShare)
                builder.add(.sessions, day: day, values: ["1.3", device, "App Store Search", "", "", "", "", "US"], counts: [old, old * 240, old / 3])
                builder.add(.crashes, day: day, values: ["1.3", device], counts: [Int((Double(old) * oldRate / 1000).rounded()), 0])
                if new > 0 {
                    builder.add(.sessions, day: day, values: ["1.4", device, "App Store Search", "", "", "", "", "US"], counts: [new, new * 230, new / 3])
                    builder.add(.crashes, day: day, values: ["1.4", device], counts: [Int((Double(new) * newRate / 1000).rounded()), 0])
                }
            }
        }
    }

    /// Installs and deletions by page: Mood tracking's are deleted twice as often.
    private static func afterDownload(into builder: inout Builder) {
        let window = AnalyticsPeriod(ending: last, length: 28)
        for (page, installs, recent, campaign) in [
            ("", 2400, 300, ""), ("Mood tracking", 400, 100, "spring-mood"), ("Sleep journal", 300, 36, "podcast-sleep"),
        ] {
            for (day, count) in spread(installs, over: window) where count > 0 {
                builder.add(.installs, day: day, values: [
                    "Install", "First-time download", "1.4", "iPhone", "App Store Search", "", campaign, "Product page", page, "", "US",
                ], counts: [count, count])
            }
            for (day, count) in spread(recent, over: window) where count > 0 {
                builder.add(.installs, day: day, values: [
                    "Delete", "", "1.4", "iPhone", "App Store Search", "", campaign, "Product page", page, "1", "US",
                ], counts: [count, count])
            }
        }
        for (day, count) in spread(62, over: window) where count > 0 {
            builder.add(.widgets, day: day, values: ["iPhone", "US"], counts: [count, count])
        }
        for (engagement, total) in [("", 1840), ("Ratings & Reviews expanded", 210), ("App Privacy details modal open", 64), ("Developer website", 31)] {
            for (day, count) in spread(total, over: window) where count > 0 {
                let action = engagement.isEmpty ? "Page View" : "Tap"
                builder.add(.webPreview, day: day, values: [action, engagement, "Product page", "", "Web Referrer"], counts: [count])
            }
        }
    }

    // MARK: - Other apps

    /// Quiet Timer: 14 people at the cancel screen, 3 stayed.
    static var quiet: ReportsArchive {
        var builder = Builder()
        let window = AnalyticsPeriod(ending: last.adding(-4), length: 28)
        for (event, total) in [("Page views", 14), ("Cancels", 11), ("Saves", 3)] {
            for (day, count) in spread(total, over: window) where count > 0 {
                let saveType = event == "Saves" ? "Don’t cancel" : ""
                builder.add(.retention, day: day, values: [
                    event, "Quiet Pro", "Text message", "Stay a while", "rm-stay", "", "", saveType, "iPhone", "US",
                ], counts: [count])
            }
        }
        builder.add(.retention, day: last, values: [
            "Page views", "Quiet Pro", "Text message", "Stay a while", "rm-stay", "", "", "", "iPhone", "US",
        ], counts: [1])
        return builder.archive(firstChecked: Data.date(month: 11, day: 1))
    }

    /// Parcel Pal: Apple sent every report, with no rows yet.
    static var parcel: ReportsArchive {
        var archive = ReportsArchive()
        archive.apply(ReportsDownload(listed: Dictionary(uniqueKeysWithValues: AppleReportKind.allCases.map { ($0, 2) })), now: Data.date(month: 11, day: 2))
        return archive
    }

    /// Tempo: asked on Nov 10, nothing from Apple yet.
    static var tempo: ReportsArchive {
        var archive = ReportsArchive()
        archive.apply(ReportsDownload(), now: Data.date(month: 11, day: 10))
        return archive
    }

    // MARK: - Helpers

    /// `total` spread over the period's days, evenly, adding up exactly.
    static func spread(_ total: Int, over period: AnalyticsPeriod) -> [(AnalyticsDay, Int)] {
        let days = period.days
        guard !days.isEmpty, total > 0 else { return [] }
        return days.enumerated().map { index, day in
            let start = total * index / days.count
            let end = total * (index + 1) / days.count
            return (day, end - start)
        }
    }

    /// Facts by kind, then one archive.
    struct Builder {
        var facts: [AppleReportKind: [ReportFact]] = [:]

        mutating func add(_ kind: AppleReportKind, day: AnalyticsDay, values: [String], counts: [Int]) {
            facts[kind, default: []].append(ReportFact(day: day, values: values, counts: counts))
        }

        func archive(firstChecked: Date) -> ReportsArchive {
            var download = ReportsDownload()
            for kind in AppleReportKind.allCases {
                let list = ReportFact.merged(facts[kind] ?? [])
                download.listed[kind] = list.isEmpty ? 0 : 30
                if !list.isEmpty {
                    download.batches.append(ReportBatch(instanceID: "debug-\(kind.rawValue)", kind: kind, processing: last, facts: list))
                }
            }
            var archive = ReportsArchive()
            archive.apply(download, now: firstChecked)
            return archive
        }
    }
}
#endif
