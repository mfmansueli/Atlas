//
//  AnalyticsBreakDownView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Break It Down (board 92): the table by country, language,
/// source, device or product page, with its inspector.
struct AnalyticsBreakDownView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onAct: (FindingAction, String) -> Void

    var body: some View {
        if let table = viewModel.table {
            BreakdownView(viewModel: viewModel, table: table, onAct: onAct)
        }
    }
}
