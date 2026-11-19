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
/// Welcome.
struct FirstSyncView: View {
    let progress: FirstSyncProgress
    /// DEBUG scenes show the Reduce Motion header without the setting.
    var forcesStill = false
    var onCancel: (() -> Void)?

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

    private func body(layout: WelcomeLayout) -> some View {
        VStack(spacing: layout.isShort ? 10 : 14) {
            Text("Reading your apps…")
                .font(.system(size: layout.isShort ? 24 : 30, weight: .bold))
                .tracking(-0.4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sync.title")
            Text(progress.summary)
                .font(.system(size: layout.isShort ? 13.5 : 15))
                .lineSpacing(layout.isShort ? 2 : 4)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("sync.summary")
            VStack(spacing: 6) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(Text("Apps read"))
                    .accessibilityValue(Text(progress.detail))
                    .accessibilityIdentifier("sync.progress")
                Text(progress.detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityHidden(true)
            }
            .frame(width: 360)
            if let onCancel {
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
