//
//  ScreenshotDeleteAllSheet.swift
//  Atlas
//

import SwiftUI

/// Delete All iPhone 6.9″ Screenshots in German?: after the push the App
/// Store shows the primary language's there; the other devices keep theirs.
struct ScreenshotDeleteAllSheet: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    private var display: ScreenshotDisplayType { viewModel.displayType }

    var body: some View {
        let count = viewModel.ownCount(locale: locale.code, displayType: display)
        ScreenshotHandSheetLayout(
            viewModel: viewModel,
            title: String(localized: "Delete All \(display.title) Screenshots in \(locale.name)?"),
            subtitle: count == 1 ? String(localized: "1 screenshot") : String(localized: "\(count) screenshots"),
            okTitle: String(localized: "Delete \(count)"),
            okRole: .destructive,
            isOKDisabled: count == 0
        ) {
            ScreenshotHandNote(text: note, isWarning: true)
        } onOK: {
            viewModel.handSheet = nil
            Task { await viewModel.deleteAllHand() }
        }
        .accessibilityIdentifier("screenshots.hand.deleteAllSheet")
    }

    private var note: String {
        let others = viewModel.pageDisplays.filter { $0 != display }.map(\.shortTitle)
        let keep = others.isEmpty ? "" : " " + String(localized: "\(ListFormatter.localizedString(byJoining: others)) keep theirs.")
        return String(localized: "After you push, the App Store shows the \(viewModel.primaryLocaleName) screenshots in \(locale.name).")
            + keep + " " + String(localized: "You can add new ones before or after pushing.")
    }
}
