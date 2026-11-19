//
//  WindowCover.swift
//  Atlas
//

import SwiftUI

/// Something shown over the whole main window, sidebar and toolbar
/// included, such as an event's artwork full size (board 47). The main
/// window draws it and hides its toolbar while it shows; a section puts
/// its view here and takes it away again.
@MainActor
@Observable
final class WindowCover {
    private(set) var id: String?
    private(set) var content: AnyView?

    var isShown: Bool { content != nil }

    func show(_ id: String, @ViewBuilder content: () -> some View) {
        self.id = id
        self.content = AnyView(content())
    }

    /// Takes `id`'s view away; another's stays.
    func hide(_ id: String) {
        guard self.id == id else { return }
        self.id = nil
        content = nil
    }
}
