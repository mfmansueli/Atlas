//
//  ToolbarTextChangeDebugScene.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// `tb-text`: the workspace toolbar's title and Autopilot button with
/// texts that change after the toolbar has measured them: the status line
/// arrives late and grows, and the button goes idle → working → done →
/// needs you → idle, with short and long words. Every step lasts
/// `ToolbarTextChangeDebugScene.stepDuration`; `-tbTextStopAt <n>` stops
/// at step n (from 0) instead of going round.
struct ToolbarTextChangeDebugScene: View {
    static let id = "tb-text"
    static let stepDuration: Duration = .seconds(3)

    /// The steps the scene goes round, in order.
    static let steps: [(status: WorkspaceSectionStatus, look: AutopilotButtonLook, title: String)] = [
        (WorkspaceSectionStatus(section: .overview), .idle, "Suggest…"),
        (
            WorkspaceSectionStatus(section: .overview, lead: "Alba: Daily Motivation · Version 1.2.2 · Not submitted yet"),
            .idle, "Suggest Everything…"
        ),
        (
            WorkspaceSectionStatus(section: .overview, waiting: 32, notPushed: 3, lead: "Alba: Daily Motivation · Version 1.2.2"),
            .working("Making screenshots · 5 of 10 captures", progress: 0.5), "Suggest Everything…"
        ),
        (WorkspaceSectionStatus(section: .overview, waiting: 1), .done("Done"), "Suggest Everything…"),
        (WorkspaceSectionStatus(section: .overview, notPushed: 12), .needsYou("Choose the Look for every device"), "Suggest Everything…"),
    ]

    @State private var step = 0

    /// The widths the title and the Autopilot button want, measured off
    /// the toolbar; the step's text reports them for the UI test.
    @State private var idealTitleWidth: CGFloat = 0
    @State private var idealAutopilotWidth: CGFloat = 0

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
                Text(verbatim: "\(Int(idealTitleWidth.rounded(.up))) \(Int(idealAutopilotWidth.rounded(.up)))")
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
                face(current)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("workspace.autopilot")
            }
            .sharedBackgroundVisibility(.hidden)
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

    private func face(_ current: (status: WorkspaceSectionStatus, look: AutopilotButtonLook, title: String)) -> some View {
        AutopilotButtonFace(look: current.look, title: current.title, accessibilityLabel: current.title, onMain: {}, menu: {
            Button("Cancel Run…") {}
        })
    }

    /// Hidden copies at their ideal size.
    private func measurements(_ current: (status: WorkspaceSectionStatus, look: AutopilotButtonLook, title: String)) -> some View {
        ZStack(alignment: .topLeading) {
            WorkspaceToolbarTitle(title: "Overview", status: current.status) {}
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { idealTitleWidth = $0 }
            face(current)
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { idealAutopilotWidth = $0 }
        }
        .hidden()
        .accessibilityHidden(true)
    }
}
#endif
