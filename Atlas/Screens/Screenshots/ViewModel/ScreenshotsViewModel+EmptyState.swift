//
//  ScreenshotsViewModel+EmptyState.swift
//  Atlas
//

import Foundation

/// Screenshots with nothing in it yet (board 74 · 4).
extension ScreenshotsViewModel {
    /// The App Store preview's place shows the empty state while the app
    /// has no screenshot anywhere and no Autopilot run is open or saved.
    var showsEmptyState: Bool {
        isLoaded && tab == .preview && !showsLanguagePage && studio.run == nil && !studio.isAutopilotPresented
            && ScreenshotsEmptyCheck.isEmpty(live: live, document: document)
    }

    /// Add Screenshots…: the primary language's page, with its Add sheet.
    func addScreenshotsByHand() {
        pageLocale = context.primaryLocale
        pageShowsAll = false
        showsLanguagePage = true
        handSheet = .add([])
    }
}
