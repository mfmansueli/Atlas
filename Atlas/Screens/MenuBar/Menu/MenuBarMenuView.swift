//
//  MenuBarMenuView.swift
//  Atlas
//

import SwiftUI

/// The menu under the menu bar icon (board 46): what's running now, each
/// with a bar and about how long is left, or "Everything is up to date"
/// with the last and next check; what needs the person, each line opening
/// Atlas at that place; then Open Atlas, Review & Push…, Check Now, Pause
/// Background Work, Pause Auto-Reply (while it's on), Settings… and Quit
/// Atlas.
struct MenuBarMenuView: View {
    let snapshot: MenuBarSnapshot
    let actions: MenuBarActions

    static let width: CGFloat = 330

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            status
            separator
            if !snapshot.needs.isEmpty {
                header("Needs you")
                ForEach(snapshot.needs) { need in
                    MenuBarItemButton(title: need.title, systemImage: need.systemImage, detail: need.detail, identifier: "menuBar.need.\(need.id)") {
                        actions.open(need.destination)
                    }
                }
                separator
            }
            MenuBarItemButton(
                title: String(localized: "Open Atlas"), systemImage: "arrow.up.forward.app", shortcut: "⌘O",
                identifier: "menuBar.openAtlas", action: actions.openAtlas
            )
            .keyboardShortcut("o", modifiers: .command)
            MenuBarItemButton(
                title: String(localized: "Review & Push…"), systemImage: "arrow.up.circle",
                count: snapshot.reviewPushCount, identifier: "menuBar.reviewPush"
            ) {
                actions.open(.reviewPush)
            }
            MenuBarItemButton(
                title: String(localized: "Check Now"), systemImage: "arrow.clockwise", shortcut: "⌘R",
                identifier: "menuBar.checkNow", action: actions.checkNow
            )
            .keyboardShortcut("r", modifiers: .command)
            MenuBarItemButton(
                title: snapshot.isPaused ? String(localized: "Resume Background Work") : String(localized: "Pause Background Work"),
                systemImage: snapshot.isPaused ? "play.circle" : "pause.circle",
                identifier: "menuBar.pause"
            ) {
                actions.setPaused(!snapshot.isPaused)
            }
            if let autoReplyPaused = snapshot.autoReplyPaused {
                MenuBarItemButton(
                    title: autoReplyPaused ? String(localized: "Resume Auto-Reply") : String(localized: "Pause Auto-Reply"),
                    systemImage: autoReplyPaused ? "play.circle" : "pause.circle",
                    identifier: "menuBar.autoReplyPause"
                ) {
                    actions.setAutoReplyPaused(!autoReplyPaused)
                }
            }
            separator
            MenuBarItemButton(
                title: String(localized: "Settings…"), systemImage: "gearshape", shortcut: "⌘,",
                identifier: "menuBar.settings", action: actions.openSettings
            )
            .keyboardShortcut(",", modifiers: .command)
            MenuBarItemButton(title: String(localized: "Quit Atlas"), systemImage: "power", shortcut: "⌘Q", identifier: "menuBar.quit", action: actions.quit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(6)
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Atlas"))
        .accessibilityIdentifier("menuBar.menu")
    }

    /// "Running now" and its jobs, or one line saying nothing runs.
    @ViewBuilder
    private var status: some View {
        if snapshot.jobs.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.quietTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(snapshot.connectionProblem == nil ? Palette.label : Palette.err)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("menuBar.quietTitle")
                Text(snapshot.checkLine)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("menuBar.checkLine")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            header("Running now")
            ForEach(snapshot.jobs) { MenuBarJobRow(job: $0) }
        }
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.label2)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private var separator: some View {
        Rectangle()
            .fill(Palette.separator)
            .frame(height: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .accessibilityHidden(true)
    }
}

#Preview {
    MenuBarMenuView(
        snapshot: MenuBarSnapshot(
            jobs: [BackgroundJob(
                id: "push", kind: .push, title: "Pushing to App Store Connect", fraction: 0.61,
                detail: "14 of 23 changes · Lumen Journal · about 1 min left"
            )],
            needs: [BackgroundNeed(
                id: "reviews", title: "6 reviews need a reply", detail: "Replies are suggested in each language",
                destination: .reviewPush, systemImage: "star.bubble"
            )],
            checkLine: "Last checked today at 18:20 · next check at 19:20",
            reviewPushCount: 4
        ),
        actions: MenuBarActions()
    )
}
