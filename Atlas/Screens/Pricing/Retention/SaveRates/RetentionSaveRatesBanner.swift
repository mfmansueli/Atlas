//
//  RetentionSaveRatesBanner.swift
//  Atlas
//

import SwiftUI

/// Where the save rates beside each message come from.
struct RetentionSaveRatesBanner: View {
    let report: RetentionReport
    let onOpen: () -> Void

    var body: some View {
        AnalyticsNotice(
            tone: .info,
            text: report.isEmpty
                ? String(localized: "No one has opened Cancel Subscription yet. Save rates show here from Analytics once Apple counts the first people, up to 4 days later.")
                : String(localized: "Save rates are from Analytics: the last \(report.period.length) days, through \(AnalyticsText.day(report.period.last.date)). Apple completes each day up to 4 days later."),
            primary: (String(localized: "Open in Analytics"), onOpen),
            identifier: "retention.saveRates.banner"
        )
    }
}
