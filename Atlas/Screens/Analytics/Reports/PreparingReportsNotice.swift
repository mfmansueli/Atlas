//
//  PreparingReportsNotice.swift
//  Atlas
//

import SwiftUI

/// The first read after the newer reports were asked for: Apple is still
/// making some of them.
struct PreparingReportsNotice: View {
    let appName: String
    let kinds: [AppleReportKind]
    let asked: Date?
    let onShow: () -> Void

    var body: some View {
        AnalyticsNotice(
            tone: .info,
            text: text,
            primary: (String(localized: "Reports from Apple…"), onShow),
            identifier: "analytics.preparingReports"
        )
    }

    private var text: String {
        let count = kinds.count
        let base = count == 1
            ? String(localized: "Apple is preparing 1 more report for \(appName).")
            : String(localized: "Apple is preparing \(count) more reports for \(appName).")
        let when = asked.map { String(localized: "Asked on \(AnalyticsText.day($0)); the first ones usually take 1 to 2 days, and Atlas checks every day.") }
            ?? String(localized: "The first ones usually take 1 to 2 days, and Atlas checks every day.")
        return base + " " + when
    }
}
