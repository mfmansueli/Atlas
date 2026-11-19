//
//  WindowCoverModifier.swift
//  Atlas
//

import SwiftUI

/// Draws the window's cover over everything, sidebar included, and hides
/// the toolbar while it shows, so the cover takes its place too.
struct WindowCoverModifier: ViewModifier {
    let cover: WindowCover

    func body(content: Content) -> some View {
        content
            .overlay {
                if let view = cover.content {
                    view
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.18), value: cover.isShown)
            .toolbar(cover.isShown ? .hidden : .automatic, for: .windowToolbar)
    }
}
