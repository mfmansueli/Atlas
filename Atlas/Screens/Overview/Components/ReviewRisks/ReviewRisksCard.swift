//
//  ReviewRisksCard.swift
//  Atlas
//

import SwiftUI

/// "2 things App Review may reject": the App Review checks' findings for
/// the app, most serious first, at most 6 before Show N More, with when
/// they ran and Check Again. Atlas's own checks (no AI): blue actions, a
/// grey line while checking.
struct ReviewRisksCard: View {
    let report: ReviewRiskReport?
    let isChecking: Bool
    let onCheck: () -> Void
    let onShow: (ReviewRisk) -> Void
    let onDismiss: (ReviewRisk) -> Void

    @State private var showsAll = false

    static let shownAtFirst = 6

    var body: some View {
        OverviewListCard(title: title, titleIdentifier: "overview.reviewRisks.title") {
            if let report {
                ForEach(shown(report)) { risk in
                    ReviewRiskRow(risk: risk, onShow: { onShow(risk) }, onDismiss: { onDismiss(risk) })
                }
                if report.risks.count > Self.shownAtFirst, !showsAll {
                    Divider()
                    Button(
                        String(
                            localized: "Show \(report.risks.count - Self.shownAtFirst) More",
                            comment: "kind:button · shows the rest of the App Review risks"
                        )
                    ) { showsAll = true }
                        .plainButton()
                        .padding(.vertical, Spacing.small)
                        .accessibilityIdentifier("overview.reviewRisks.showMore")
                }
            }
            footer
        }
        .accessibilityIdentifier("overview.reviewRisks")
    }

    private var title: String {
        report?.summary ?? String(localized: "App Review check", comment: "kind:title · the Overview card of App Review risks")
    }

    private func shown(_ report: ReviewRiskReport) -> [ReviewRisk] {
        showsAll ? report.risks : Array(report.risks.prefix(Self.shownAtFirst))
    }

    /// "Checked 5 min ago · 2 checks need the project" and Check Again.
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Spacing.medium) {
                Text(footerText)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("overview.reviewRisks.footer")
                Button(buttonTitle, action: onCheck)
                    .secondaryButton()
                    .fixedSize()
                    .disabled(isChecking)
                    .accessibilityIdentifier("overview.reviewRisks.check")
            }
            .padding(.vertical, 10)
        }
    }

    private var buttonTitle: String {
        if isChecking { return String(localized: "Checking…", comment: "kind:button · App Review checks running") }
        return report == nil
            ? String(localized: "Check Now", comment: "kind:button · runs the App Review checks")
            : String(localized: "Check Again", comment: "kind:button · runs the App Review checks again")
    }

    private var footerText: String {
        guard let report else {
            return String(
                localized: "Atlas reads the store page, products, links and age rating for what App Review rejects.",
                comment: "kind:summary · before the first App Review check"
            )
        }
        let checked = String(
            localized: "Checked \(report.checkedAt.formatted(.relative(presentation: .named)))",
            comment: "kind:caption · when the App Review checks last ran"
        )
        let gaps = report.notChecked.count
        guard gaps > 0 else { return checked }
        let gapText = gaps == 1
            ? String(localized: "1 check couldn’t run", comment: "kind:caption · App Review checks that couldn't run")
            : String(localized: "\(gaps) checks couldn’t run", comment: "kind:caption · App Review checks that couldn't run")
        return "\(checked) · \(gapText)"
    }
}
