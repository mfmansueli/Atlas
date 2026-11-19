//
//  MenuBarLiveMenu.swift
//  Atlas
//

import SwiftUI

/// The menu as `BackgroundWork` has it now, again every second so the
/// bars move and "about 6 min left" counts down while it's open.
struct MenuBarLiveMenu: View {
    let work: BackgroundWork
    let actions: MenuBarActions

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            MenuBarMenuView(snapshot: work.snapshot(at: context.date), actions: actions)
        }
    }
}
