//
//  AskAnchor.swift
//  Atlas
//

import AppKit

/// The AppKit view behind a button (`AskAnchorView`), read when a request
/// is sent: where the token starts, or where it lands.
@MainActor
final class AskAnchor {
    weak var view: NSView?

    /// The view's frame on screen, while it's shown in a window.
    var screenFrame: CGRect? {
        guard let view, let window = view.window, !view.isHiddenOrHasHiddenAncestor, view.bounds.width > 0, view.bounds.height > 0 else {
            return nil
        }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}
