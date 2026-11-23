//
//  PageShotsMakeButton.swift
//  Atlas
//

import SwiftUI

/// Make Screenshots for This Page… (board 52), a Pro feature like
/// Autopilot: opens the page's screenshot run, starting one when there's
/// none. Off while the page is with App Review or the key can't change
/// pages.
struct PageShotsMakeButton: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        Button {
            let open = { Task { await viewModel.openPageShots(page) } }
            if let pro { pro.require(.autopilot) { _ = open() } } else { _ = open() }
        } label: {
            Label("Make Screenshots for This Page…", systemImage: "sparkles")
        }
        .controlSize(.regular)
        .disabled(isLocked || !viewModel.canChange || viewModel.makePageShotsFlow == nil)
        .help(Text("Makes this page’s own set from the default page’s screens. The default page stays."))
        .accessibilityIdentifier("pages.screenshots.make")
    }

    private var isLocked: Bool { page.editing?.state.isLocked == true }
}
