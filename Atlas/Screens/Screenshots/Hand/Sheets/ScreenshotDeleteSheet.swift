//
//  ScreenshotDeleteSheet.swift
//  Atlas
//

import SwiftUI

/// Delete Screenshot n?: what the set keeps, in this language or every
/// language. The primary language's last screenshot can't go.
struct ScreenshotDeleteSheet: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let item: ScreenshotHandPageItem
    let locale: StoreLocale

    @State private var scope: ScreenshotHandScope = .one

    private var display: ScreenshotDisplayType { item.cell.key.displayType }
    private var ownCount: Int { viewModel.ownLocales(on: display).count }
    private var isLastPrimary: Bool { !viewModel.canDeleteHand(item) }

    var body: some View {
        ScreenshotHandSheetLayout(
            viewModel: viewModel,
            title: String(localized: "Delete Screenshot \(item.position + 1)?"),
            subtitle: "\(locale.name) · \(display.title)",
            okTitle: scope == .every ? String(localized: "Delete in \(ownCount) Languages") : String(localized: "Delete"),
            okRole: .destructive,
            isOKDisabled: isLastPrimary
        ) {
            HStack(alignment: .center, spacing: Spacing.medium) {
                ScreenshotHandCurrentImage(viewModel: viewModel, cell: item.cell, label: nil)
                Text(explanation)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("screenshots.hand.delete.explanation")
            }
            if !isLastPrimary {
                ScreenshotHandScopeOptions(label: String(localized: "Delete it from"), options: [
                    .init(scope: .one, title: String(localized: "Only \(locale.name)"),
                          detail: String(localized: "The other languages keep their screenshot \(item.position + 1).")),
                    .init(scope: .every, title: String(localized: "Every language (\(ownCount))"),
                          detail: String(localized: "Screenshot \(item.position + 1) goes in each of them."), isDisabled: ownCount < 2),
                ], selection: $scope)
            }
        } onOK: {
            viewModel.handSheet = nil
            Task { await viewModel.deleteHand(slotID: item.id, scope: scope) }
        }
        .accessibilityIdentifier("screenshots.hand.deleteSheet")
    }

    private var explanation: String {
        let primary = viewModel.primaryLocaleName
        if isLastPrimary {
            return String(localized: "Apple needs at least one \(display.title) screenshot in \(primary), the primary language.")
        }
        let left = viewModel.ownCount(locale: locale.code, displayType: display) - 1
        if left == 1 {
            return String(localized: "\(locale.name) keeps 1 \(display.title) screenshot; later ones move up.")
        }
        if left > 1 {
            return String(localized: "\(locale.name) keeps \(left) \(display.title) screenshots; later ones move up.")
        }
        return String(localized: "The App Store will show the \(primary) \(display.title) screenshots in \(locale.name) instead.")
    }
}
