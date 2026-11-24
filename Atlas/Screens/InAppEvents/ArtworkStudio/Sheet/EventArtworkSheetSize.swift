//
//  EventArtworkSheetSize.swift
//  Atlas
//

import AppKit

/// How big the Brief sheet is: 940 × 720, less in a smaller window (40
/// points narrower and 48 shorter than it, at least 780 × 500). And
/// whether a new look is offered.
@MainActor
enum EventArtworkSheetSize {
    static let preferred = CGSize(width: 940, height: 720)
    static let smallest = CGSize(width: 780, height: 500)

    static func fitting(_ window: CGSize?) -> CGSize {
        guard let window else { return preferred }
        return CGSize(
            width: max(smallest.width, min(preferred.width, window.width - 40)),
            height: max(smallest.height, min(preferred.height, window.height - 48))
        )
    }

    /// The size for the app's window. With Atlas in the background (no
    /// main or key window) it reads the visible document window, so the
    /// sheet still fits a small one.
    static var current: CGSize {
        let window = NSApp.mainWindow ?? NSApp.keyWindow
            ?? NSApp.windows.first { $0.isVisible && $0.sheetParent == nil && $0.styleMask.contains(.titled) }
        return fitting(window?.contentLayoutRect.size)
    }

    /// A design project is connected to the app, so Claude can draw
    /// a new look in its brand. DEBUG scenes say so themselves.
    static func hasDesignSystem(_ appID: StoreApp.ID) -> Bool {
        #if DEBUG
        if let override = debugHasDesignSystem { return override }
        #endif
        return AutopilotCenter.shared.designProject(for: appID) != nil
    }

    #if DEBUG
    static var debugHasDesignSystem: Bool?
    #endif
}
