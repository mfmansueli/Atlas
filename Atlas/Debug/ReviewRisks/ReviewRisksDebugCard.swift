//
//  ReviewRisksDebugCard.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Overview's App Review card on its own, with Dismiss and Check
/// Again working on the sample report.
struct ReviewRisksDebugCard: View {
    @State var report: ReviewRiskReport?
    @State private var isChecking = false

    var body: some View {
        ScrollView {
            ReviewRisksCard(
                report: report,
                isChecking: isChecking,
                onCheck: {
                    isChecking = true
                    report = report ?? ReviewRisksDebugData.report(ReviewRisksDebugData.risks)
                    isChecking = false
                },
                onShow: { _ in },
                onDismiss: { risk in report?.risks.removeAll { $0.id == risk.id } }
            )
            .padding(Spacing.xLarge)
            .frame(maxWidth: 700)
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}
#endif
