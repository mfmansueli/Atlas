//
//  AnalyticsWhatToTryView.swift
//  Atlas
//

import SwiftUI

/// Analytics → What to Try (board 92): the findings, each opening the
/// section where the change is made.
struct AnalyticsWhatToTryView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let waitingCount: (AnalyticsFinding) -> Int
    let onAct: (AnalyticsFinding, FindingAction) -> Void

    var body: some View {
        FindingsView(viewModel: viewModel, waitingCount: waitingCount, onAct: onAct)
    }
}
