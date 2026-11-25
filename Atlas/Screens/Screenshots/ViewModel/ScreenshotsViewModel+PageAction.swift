//
//  ScreenshotsViewModel+PageAction.swift
//  Atlas
//

import Foundation

/// Add Screenshots… in the toolbar (board 80): files for the language and
/// device on screen, or the primary language's when none is.
extension ScreenshotsViewModel {
    /// Off until the sets are read, and on a language page whose set on
    /// this device is full.
    var pageActionState: WorkspacePageActionState {
        guard isLoaded else { return .disabled(reason: nil) }
        guard showsLanguagePage, !pageShowsAll, isPageSetFull else { return .enabled }
        return .disabled(reason: String(
            localized: "\(currentPageLocale.name) has 10 screenshots on \(displayType.title), Apple’s most.", comment: "kind:tooltip"
        ))
    }

    /// The language page with its Add sheet; with a full set, the page
    /// alone, to replace or delete first.
    func startPageAction() {
        guard isLoaded else { return }
        pageShowsAll = false
        showsLanguagePage = true
        if !isPageSetFull { handSheet = .add([]) }
    }

    /// The language page's set on this device has as many as Apple takes.
    private var isPageSetFull: Bool {
        ownCount(locale: currentPageLocale.code, displayType: displayType) >= ScreenshotHandSet.capacity
    }
}
