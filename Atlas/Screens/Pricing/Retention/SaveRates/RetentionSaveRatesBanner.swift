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
                ? String(localized: "No one has opened Cancel Subscription yet. Save rates show here up to 4 days after the first.")
                : String(localized: "Save rates for \(report.period.length) days through \(AnalyticsText.day(report.period.last.date)), from Analytics. Days finish up to 4 days late."),
            primary: (String(localized: "Open in Analytics"), onOpen),
            identifier: "retention.saveRates.banner"
        )
    }
}
