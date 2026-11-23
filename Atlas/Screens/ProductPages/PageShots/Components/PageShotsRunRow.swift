//
//  PageShotsRunRow.swift
//  Atlas
//

import SwiftUI

/// The page's screenshot run while its sheet is closed: Autopilot under
/// way with how far it got, the plan or the set waiting for the person,
/// and Show.
struct PageShotsRunRow: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage

    var body: some View {
        if let run = viewModel.pageShotsRun(of: page), let text = text(run) {
            HStack(spacing: Spacing.small) {
                if run.stage.isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("pages.screenshots.run.text")
                Button("Show") { Task { await viewModel.openPageShots(page) } }
                    .controlSize(.regular)
                    .accessibilityIdentifier("pages.screenshots.run.show")
            }
            .padding(Spacing.small)
            .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            // Contain, not combine: Show stays a button of its own.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pages.screenshots.run")
        }
    }

    private func text(_ run: PageShotsRun) -> String? {
        let assistant = run.plan?.source ?? "Claude Code"
        switch run.stage {
        case .planning: return String(localized: "\(assistant) is planning this page’s screenshots.")
        case .plan: return String(localized: "The plan for this page’s screenshots is ready. Look at it, then start Autopilot.")
        case .making:
            return String(localized: "Autopilot is making this page’s screenshots · \(run.images.count) of \(run.expectedCount)")
        case .revising: return String(localized: "\(assistant) is changing this page’s screenshots.")
        case .result: return String(localized: "This page’s new screenshots are ready. Choose where they’re used.")
        case .used: return nil
        }
    }
}
