//
//  ScreenshotHandSheetView.swift
//  Atlas
//

import SwiftUI

/// The sheet for a change made by hand on the language page.
struct ScreenshotHandSheetView: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let sheet: ScreenshotHandSheet
    let locale: StoreLocale

    var body: some View {
        switch sheet {
        case let .replace(slotID, file):
            if let item = item(slotID) {
                ScreenshotReplaceSheet(viewModel: viewModel, item: item, locale: locale, initialFile: file)
            } else {
                gone
            }
        case let .delete(slotID):
            if let item = item(slotID) {
                ScreenshotDeleteSheet(viewModel: viewModel, item: item, locale: locale)
            } else {
                gone
            }
        case .deleteAll:
            ScreenshotDeleteAllSheet(viewModel: viewModel, locale: locale)
        case let .add(files):
            ScreenshotAddSheet(viewModel: viewModel, locale: locale, initialFiles: files)
        case .importFolder:
            ScreenshotImportFolderSheet(viewModel: viewModel)
        }
    }

    private func item(_ slotID: String) -> ScreenshotHandPageItem? {
        viewModel.handPageItems(locale: locale.code, displayType: viewModel.displayType).first { $0.id == slotID }
    }

    /// The screenshot changed while the sheet opened (a reload): nothing
    /// left to act on.
    private var gone: some View {
        ScreenshotHandSheetLayout(
            viewModel: viewModel, title: String(localized: "Screenshot not found"),
            subtitle: String(localized: "The set changed. Select the screenshot again."), okTitle: String(localized: "OK"), isOKDisabled: false
        ) {
            EmptyView()
        } onOK: {
            viewModel.handSheet = nil
        }
    }
}
