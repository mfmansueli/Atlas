//
//  PageShotsSheet.swift
//  Atlas
//

import SwiftUI

/// Screenshots for “<page>” (board 52): Autopilot in three steps, Plan,
/// Making and Result, for one custom product page. The default page's
/// screenshots never change. Closing it while it works hides it: the run
/// keeps going, and the page's editor shows it.
struct PageShotsSheet: View {
    @Bindable var flow: PageShotsFlow
    /// The default page's set in a language on a device, for Result.
    let defaultSet: (String, ProductPageDevice) -> LoadState<[LiveScreenshot]>
    let viewModel: ProductPagesViewModel

    var body: some View {
        let size = EventArtworkSheetSize.current
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.large)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height)
        .task { await flow.loadSource() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.shots.sheet")
    }

    private var stage: PageShotsStage { flow.run?.stage ?? .planning }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Screenshots for “\(flow.page.name)”")
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("pages.shots.title")
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .accessibilityIdentifier("pages.shots.subtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PageShotsStepsView(current: stage.step)
        }
    }

    private var subtitle: String {
        switch stage.step {
        case .plan: String(localized: "Autopilot makes a set for this page only. The default page’s screenshots don’t change.")
        case .making: String(localized: "Autopilot is working. You don’t have to wait here.")
        case .result: String(localized: "The new set beside the default page’s. Choose where it’s used.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let problem = flow.problem, flow.run == nil || flow.source == nil {
            PageShotsProblemView(flow: flow, problem: problem)
        } else if flow.source == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let source = flow.source {
            switch stage.step {
            case .plan: PageShotsPlanStep(flow: flow, source: source)
            case .making: PageShotsMakingStep(flow: flow, source: source)
            case .result: PageShotsResultStep(flow: flow, defaultSet: defaultSet, viewModel: viewModel)
            }
        }
    }
}
