//
//  SidebarMaterialBackground.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The sidebar's own translucent material, for something pinned over the
/// sidebar's list (its footer) that rows scroll under: they don't show
/// through, and it still looks like the sidebar.
struct SidebarMaterialBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
