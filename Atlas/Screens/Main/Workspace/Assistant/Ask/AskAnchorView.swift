//
//  AskAnchorView.swift
//  Atlas
//

import AppKit
import SwiftUI

/// An empty AppKit view behind a button, kept in `anchor`, so the token
/// knows where the button is when the request is sent. SwiftUI's own
/// coordinate spaces don't reach the toolbar.
struct AskAnchorView: NSViewRepresentable {
    let anchor: AskAnchor

    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        view.setAccessibilityElement(false)
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context _: Context) {
        anchor.view = view
    }
}
