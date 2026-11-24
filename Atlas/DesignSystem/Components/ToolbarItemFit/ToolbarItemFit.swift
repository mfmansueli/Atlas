//
//  ToolbarItemFit.swift
//  Atlas
//

import SwiftUI

/// Keeps a toolbar item as wide as its content (`ToolbarItemFitView`). Use
/// it through `.toolbarItemFit(_:)` on the content of every toolbar item
/// whose width changes: its texts, its compact form.
struct ToolbarItemFit<Key: Hashable>: NSViewRepresentable {
    /// What changes the content's width; a new value checks the item again.
    let key: Key

    func makeNSView(context _: Context) -> ToolbarItemFitView {
        ToolbarItemFitView()
    }

    func updateNSView(_ nsView: ToolbarItemFitView, context: Context) {
        guard context.coordinator.key != key else { return }
        context.coordinator.key = key
        nsView.refit()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// The last key seen, so only a change refits.
    final class Coordinator {
        var key: Key?
    }
}

extension View {
    /// Keeps the toolbar item this content is in as wide as the content
    /// wants, when `key` changes and when the window resizes.
    func toolbarItemFit(_ key: some Hashable) -> some View {
        background(ToolbarItemFit(key: key).accessibilityHidden(true))
    }
}
