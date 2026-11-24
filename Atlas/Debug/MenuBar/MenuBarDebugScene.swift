//
//  MenuBarDebugScene.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// One menu bar scene: the menu (or the "still running" note) on a
/// desktop-blue backdrop, in a panel drawn like the real one, acting on
/// its own canned snapshot.
struct MenuBarDebugScene: View {
    let note: Bool
    @State var snapshot: MenuBarSnapshot
    /// What the last line clicked would have done.
    @State private var lastAction = ""
    @State private var isNoteShown = true

    init(note: Bool, snapshot: MenuBarSnapshot) {
        self.note = note
        _snapshot = State(initialValue: snapshot)
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            panel
            Text(lastAction)
                .font(.callout)
                .foregroundStyle(.white)
                .accessibilityIdentifier("menuBarScene.lastAction")
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(white: 0.35), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
        .navigationTitle("Atlas")
    }

    @ViewBuilder
    private var panel: some View {
        if note {
            if isNoteShown {
                StillRunningNote(
                    onQuitWhenClosed: { done("Quit When Window Closes") },
                    onDismiss: { done("Got It") }
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
            }
        } else {
            MenuBarMenuView(snapshot: snapshot, actions: actions)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        }
    }

    private func done(_ action: String) {
        isNoteShown = false
        lastAction = action
    }

    private var actions: MenuBarActions {
        MenuBarActions(
            openAtlas: { lastAction = "Open Atlas" },
            open: { lastAction = Self.describe($0) },
            checkNow: { check() },
            setPaused: { paused in
                snapshot.isPaused = paused
                lastAction = paused ? "Paused" : "Resumed"
            },
            setAutoReplyPaused: { paused in
                snapshot.autoReplyPaused = paused
                lastAction = paused ? "Auto-reply paused" : "Auto-reply resumed"
            },
            openSettings: { lastAction = "Settings" },
            quit: { lastAction = "Quit" }
        )
    }

    private func check() {
        lastAction = "Check Now"
        let jobs = snapshot.jobs
        snapshot.jobs = jobs + [BackgroundJob(
            id: "check", kind: .check, title: "Checking App Store Connect", fraction: nil,
            detail: "Reviews, version status and analytics reports"
        )]
        Task {
            try? await Task.sleep(for: .seconds(3))
            snapshot.jobs = jobs
            snapshot.checkLine = "Last checked just now · next check in 1 hour"
        }
    }

    private static func describe(_ destination: BackgroundDestination) -> String {
        switch destination {
        case let .section(section, appID): "Open \(section) of \(appID)"
        case let .version(appID): "Open the version of \(appID)"
        case let .currentSection(section): "Open \(section)"
        case .reviewPush: "Open Review & Push"
        case let .eventArtwork(appID, eventID): "Open the artwork of \(eventID) of \(appID)"
        }
    }
}
#endif
