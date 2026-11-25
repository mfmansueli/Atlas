//
//  ScreenshotHandManageMenu.swift
//  Atlas
//

import SwiftUI

/// Manage ▾ beside the device switch: Add Screenshots…, Import a Folder…
/// and Delete All iPhone 6.9″ Screenshots in German….
struct ScreenshotHandManageMenu: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    var body: some View {
        let display = viewModel.displayType
        let count = viewModel.ownCount(locale: locale.code, displayType: display)
        Menu {
            Button("Add Screenshots…", systemImage: "plus") { viewModel.handSheet = .add([]) }
                .disabled(count >= ScreenshotHandSet.capacity)
            Button("Import a Folder…", systemImage: "folder") { viewModel.handSheet = .importFolder }
            Divider()
            Button("Delete All \(display.title) Screenshots in \(locale.name)…", systemImage: "trash", role: .destructive) {
                viewModel.handSheet = .deleteAll
            }
            .disabled(count == 0 || locale.code == viewModel.context.primaryLocale.code)
        } label: {
            Text("Manage")
        }
        .menuStyle(.button)
        .fixedSize()
        .accessibilityIdentifier("screenshots.hand.manage")
    }
}
