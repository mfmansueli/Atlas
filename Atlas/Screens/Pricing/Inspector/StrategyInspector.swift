//
//  StrategyInspector.swift
//  Atlas
//

import SwiftUI

/// Customize Suggestions… (board 73, `pr-prod-insp`): the strategy
/// inspector beside the product's prices, or floating over them at
/// 860 × 560. Method, base country and price, price index, fallback chain,
/// limits and how sure; changing anything makes the strategy Custom, and
/// Use Built-in resets it. The prices update live.
struct StrategyInspector: View {
    @Bindable var viewModel: PricingViewModel
    /// Over the page instead of in an inspector column.
    var isFloating = false
    let onImport: () -> Void

    var body: some View {
        let isCustom = viewModel.strategy.strategy.isCustom
        VStack(spacing: 0) {
            VStack(spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    Text("Customize Suggestions", comment: "kind:sheet-title")
                        .atlasTextStyle(.headline)
                    Spacer()
                    Pill(text: isCustom
                        ? String(localized: "Custom", comment: "kind:pill")
                        : String(localized: "Built-in", comment: "kind:pill"))
                        .accessibilityLabel(isCustom
                            ? String(localized: "Custom strategy", comment: "kind:accessibility-label")
                            : String(localized: "Built-in strategy", comment: "kind:accessibility-label"))
                    Button {
                        viewModel.isInspectorPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(isFloating ? .cancelAction : nil)
                    .accessibilityLabel(String(localized: "Close inspector", comment: "kind:accessibility-label"))
                    .accessibilityIdentifier("pricing.inspector.close")
                }
                if isCustom {
                    Button {
                        viewModel.resetStrategy()
                    } label: {
                        Label(String(localized: "Use Built-in", comment: "kind:button"), systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryButton()
                    .controlSize(.regular)
                    .accessibilityIdentifier("pricing.inspector.useBuiltIn")
                }
            }
            .padding(Spacing.large)
            Divider()
            ScrollView {
                StrategyTab(viewModel: viewModel, onImport: onImport)
            }
            .leavesChatRoom()
        }
        .inspectorColumnWidth(Metrics.inspectorWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.inspector")
    }
}
