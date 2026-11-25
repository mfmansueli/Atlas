//
//  ReviewRiskReport.swift
//  Atlas
//

import Foundation

/// Every App Review risk found in one app, most serious first, with the
/// checks that couldn't run.
struct ReviewRiskReport: Codable, Hashable, Sendable {
    var appID: String
    var appName: String
    var checkedAt: Date
    /// The version the checks read, e.g. "1.4"; nil without one.
    var versionString: String?
    var risks: [ReviewRisk]
    var notChecked: [ReviewRiskGap]
    /// Risks the person dismissed, left out of `risks`.
    var dismissedCount = 0

    var blockingCount: Int { risks.count { $0.level == .blocksReview } }

    var isClear: Bool { risks.isEmpty }

    func risks(in section: AppWorkspaceSection) -> [ReviewRisk] {
        risks.filter { $0.check.section == section }
    }

    /// "2 things App Review may reject" — the summary line.
    var summary: String {
        switch risks.count {
        case 0: String(localized: "Nothing App Review is likely to reject", comment: "kind:summary · App Review risks")
        case 1: String(localized: "1 thing App Review may reject", comment: "kind:summary · App Review risks")
        default: String(localized: "\(risks.count) things App Review may reject", comment: "kind:summary · App Review risks")
        }
    }
}
