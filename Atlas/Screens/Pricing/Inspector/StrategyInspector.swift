//
//  StrategyInspector.swift
//  Atlas
//

import SwiftUI

/// Customize…: the strategy inspector beside the matrix. Changing anything
/// turns the strategy Custom; the matrix updates live.
struct StrategyInspector: View {
    @Bindable var viewModel: PricingViewModel
    let onImport: () -> Void

    var body: some View {
        let isCustom = viewModel.strategy.strategy.isCustom
        VStack(spacing: 0) {
            VStack(spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    Text("Strategy").font(.body.weight(.semibold))
                    Spacer()
                    Pill(text: isCustom ? String(localized: "Custom") : String(localized: "Suggested"))
                        .accessibilityLabel(isCustom ? String(localized: "Custom strategy") : String(localized: "Suggested strategy"))
                    Button {
                        viewModel.isInspectorPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "Close inspector"))
                }
                if isCustom {
                    Button {
                        viewModel.resetStrategy()
                    } label: {
                        Label("Back to Suggested", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                    .accessibilityIdentifier("pricing.inspector.backToRecommended")
                }
                Picker(String(localized: "Inspector tab"), selection: $viewModel.inspectorTab) {
                    ForEach(StrategyInspectorTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("pricing.inspector.tabs")
            }
            .padding(Spacing.large)
            Divider()
            ScrollView {
                switch viewModel.inspectorTab {
                case .strategy:
                    StrategyTab(viewModel: viewModel, onImport: onImport)
                case .territory:
                    TerritoryTab(viewModel: viewModel, matrix: viewModel.matrix)
                }
            }
        }
        .inspectorColumnWidth(Metrics.inspectorWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.inspector")
    }
}
