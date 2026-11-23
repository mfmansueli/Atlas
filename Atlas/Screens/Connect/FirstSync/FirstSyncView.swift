//
//  FirstSyncView.swift
//  Atlas
//

import SwiftUI

/// "Reading your apps…" (board 45): the large welcome header back, with
/// the tiles at double speed, in place of the library right after a key
/// is connected, until every app's summaries have loaded once. It counts
/// the apps as they're read and says nothing is changed in App Store
/// Connect. Cancel forgets the key just connected and goes back to
/// Welcome. Once every app is read, "Your 6 apps are ready" waits for
/// Open Atlas.
struct FirstSyncView: View {
    let progress: FirstSyncProgress
    /// DEBUG scenes show the Reduce Motion header without the setting.
    var forcesStill = false
    var onCancel: (() -> Void)?
    /// Set once every app is read: the done step, with Open Atlas.
    var onOpen: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let layout = WelcomeLayout(windowSize: geometry.size)
            VStack(spacing: 0) {
                WelcomeHeader(style: .large, markSize: layout.largeMarkSize, pace: 2, forcesStill: forcesStill)
                    .frame(height: layout.largeHeaderHeight)
                body(layout: layout)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle("Atlas")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sync.view")
    }

    private var isDone: Bool { onOpen != nil }

    private func body(layout: WelcomeLayout) -> some View {
        VStack(spacing: layout.isShort ? 10 : 14) {
            Group {
                if isDone {
                    Text(progress.doneTitle)
                } else {
                    Text("Reading your apps…")
                }
            }
            .font(layout.isShort ? .largeTitle.bold() : .display)
            .tracking(-0.4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("sync.title")
            Text(isDone ? progress.doneSummary : progress.summary)
                .font(layout.isShort ? .body : .title3)
                .lineSpacing(layout.isShort ? 2 : 4)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("sync.summary")
            VStack(spacing: 6) {
                ProgressView(value: isDone ? 1 : progress.fraction)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(Text("Apps read"))
                    .accessibilityValue(Text(detail))
                    .accessibilityIdentifier("sync.progress")
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityHidden(true)
            }
            .frame(width: 360)
            if let onOpen {
                Button(String(localized: "Open Atlas", comment: "kind:button"), action: onOpen)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("sync.open")
            } else if let onCancel {
                Button("Cancel", action: onCancel)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("sync.cancel")
            }
        }
        .padding(.top, layout.isShort ? 12 : 18)
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detail: String {
        isDone ? progress.doneDetail : progress.detail
    }
}

#Preview {
    FirstSyncView(
        progress: FirstSyncProgress(
            appCount: 6, syncedCount: 3, teamName: "Northpier Studio", syncedNames: ["Lumen Journal", "Habitat", "Tempo"]
        ),
        onCancel: {}
    )
    .frame(width: 1200, height: 780)
}
