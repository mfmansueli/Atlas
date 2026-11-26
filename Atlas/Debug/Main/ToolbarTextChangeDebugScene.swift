//
//  ToolbarTextChangeDebugScene.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// `tb-text`: the workspace toolbar's title and a button with texts that
/// change after the toolbar has measured them: the status line arrives
/// late and grows, and the button's words go short → long → short. Every step lasts
/// `ToolbarTextChangeDebugScene.stepDuration`; `-tbTextStopAt <n>` stops
/// at step n (from 0) instead of going round.
struct ToolbarTextChangeDebugScene: View {
    static let id = "tb-text"
    static let stepDuration: Duration = .seconds(3)

    /// The steps the scene goes round, in order.
    static let steps: [(status: WorkspaceSectionStatus, title: String)] = [
        (WorkspaceSectionStatus(section: .overview), "New…"),
        (WorkspaceSectionStatus(section: .overview, lead: "Alba: Daily Motivation · Version 1.2.2 · Not submitted yet"), "New Page…"),
        (
            WorkspaceSectionStatus(section: .overview, waiting: 32, notPushed: 3, lead: "Alba: Daily Motivation · Version 1.2.2"),
            "New Custom Product Page…"
        ),
        (WorkspaceSectionStatus(section: .overview, waiting: 1), "New Event…"),
        (WorkspaceSectionStatus(section: .overview, notPushed: 12), "New In-App Event…"),
    ]

    @State private var step = 0

    /// The widths the title and the button want, measured off
    /// the toolbar; the step's text reports them for the UI test.
    @State private var idealTitleWidth: CGFloat = 0
    @State private var idealButtonWidth: CGFloat = 0

    var body: some View {
        let current = Self.steps[step]
        NavigationSplitView {
            List {
                Text("Overview")
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 256, max: 360)
        } detail: {
            VStack(spacing: 8) {
                Text("Step \(step + 1) of \(Self.steps.count)")
                    .accessibilityIdentifier("tbText.step")
                Text(verbatim: "\(Int(idealTitleWidth.rounded(.up))) \(Int(idealButtonWidth.rounded(.up)))")
                    .accessibilityIdentifier("tbText.idealWidths")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(alignment: .topLeading) { measurements(current) }
        }
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                WorkspaceToolbarTitle(title: "Overview", status: current.status) {}
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.flexible)
            ToolbarItem(placement: .primaryAction) {
                button(current.title)
                    .accessibilityIdentifier("tbText.button")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {} label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .controlSize(.large)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            let stop = UserDefaults.standard.string(forKey: "tbTextStopAt").flatMap { Int($0) }
            while !Task.isCancelled, step != stop {
                try? await Task.sleep(for: Self.stepDuration)
                step = (step + 1) % Self.steps.count
            }
        }
    }

    private func button(_ title: String) -> some View {
        Button {} label: {
            Label(title, systemImage: "plus")
                .labelStyle(.titleAndIcon)
        }
        .controlSize(.large)
    }

    /// Hidden copies at their ideal size.
    private func measurements(_ current: (status: WorkspaceSectionStatus, title: String)) -> some View {
        ZStack(alignment: .topLeading) {
            WorkspaceToolbarTitle(title: "Overview", status: current.status) {}
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { idealTitleWidth = $0 }
            button(current.title)
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { idealButtonWidth = $0 }
        }
        .hidden()
        .accessibilityHidden(true)
    }
}
#endif
