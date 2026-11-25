//
//  AddKeySheetLayout.swift
//  Atlas
//

import AppKit

/// How big "Add Another Key…" is (the canvas's Redesign `addkey` sheet):
/// 920 × 700, and in a smaller window 32 points narrower and shorter than
/// it, so the sheet always fits inside the window it's over. Never under
/// 600 × 440, where the cards stack and the form scrolls.
enum AddKeySheetLayout {
    static let preferred = CGSize(width: 920, height: 700)
    static let smallest = CGSize(width: 600, height: 440)
    /// How much smaller than its window the sheet is, across and down.
    static let margin: CGFloat = 32

    /// The sheet's size over a window whose content is `window` big; the
    /// preferred size while the window isn't known yet.
    static func size(fitting window: CGSize?) -> CGSize {
        guard let window, window.width > 0, window.height > 0 else { return preferred }
        return CGSize(
            width: max(smallest.width, min(preferred.width, window.width - margin)),
            height: max(smallest.height, min(preferred.height, window.height - margin))
        )
    }

    /// The size for the window the sheet opens over: the one clicked (the
    /// main window or Settings). With Atlas in the background (DEBUG scenes
    /// launched from the command line) it reads the visible document
    /// window. `SheetParentSizeReader` corrects it once the sheet is up.
    @MainActor static var current: CGSize {
        let key = NSApp.keyWindow
        let window = key?.sheetParent ?? key ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && $0.sheetParent == nil && $0.styleMask.contains(.titled) }
        return size(fitting: window?.contentLayoutRect.size)
    }
}
