//
//  AutopilotButtonDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of the Autopilot button's animation (board 57, “While
/// it works”), each look on its own, outside the toolbar:
///
/// - `ap-btn`: idle, working, working with progress, done, needs you,
///   failed and Reply Automatically, one under another.
/// - `ap-btn-cycle`: one button going round: working while its bar fills
///   in steps, done for 2 s, idle, again.
enum AutopilotButtonDebugScenes {
    static let ids = ["ap-btn", "ap-btn-cycle"]

    /// Every look, with the design's words.
    static let looks: [(name: String, look: AutopilotButtonLook)] = [
        ("Idle", .idle),
        ("Working", .working("Working · Store Page · German", progress: nil)),
        ("Working, progress known", .working("Making screenshots · 5 of 10 captures", progress: 0.5)),
        ("Done", .done("Done · Store Page · German")),
        ("Needs you", .needsYou("Choose the Look")),
        ("Failed", .failed("Claude Code couldn’t reach Atlas")),
        ("Reply Automatically", .autoReplyOn("Auto-reply on · 2 sent today")),
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "ap-btn": AnyView(Gallery())
        case "ap-btn-cycle": AnyView(Cycle())
        default: nil
        }
    }

    private struct Gallery: View {
        var body: some View {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 18) {
                ForEach(AutopilotButtonDebugScenes.looks, id: \.name) { item in
                    GridRow {
                        Text(item.name)
                            .foregroundStyle(Palette.label2)
                        AutopilotButtonFace(look: item.look, title: "Suggest Texts…", accessibilityLabel: item.name, onMain: {}, menu: {
                            Button("Suggest for English (U.S.) Only…") {}
                        })
                        .fixedSize()
                    }
                }
            }
            .padding(32)
            .frame(minWidth: 640, minHeight: 420, alignment: .topLeading)
            .accessibilityIdentifier("apButton.gallery")
        }
    }

    /// Working in ten steps of 0.6 s, done for 2 s, idle for 2 s.
    private struct Cycle: View {
        @State private var look: AutopilotButtonLook = .idle
        @State private var doneCount = 0

        var body: some View {
            AutopilotButtonFace(look: look, title: "Suggest Texts…", doneCount: doneCount, accessibilityLabel: look.text ?? "Suggest Texts", onMain: {}, menu: {
                Button("Cancel Run…") {}
            })
            .fixedSize()
            .padding(48)
            .frame(minWidth: 520, minHeight: 200)
            .task {
                while !Task.isCancelled {
                    for step in 0...10 {
                        look = .working("Making screenshots · \(step) of 10 captures", progress: Double(step) / 10)
                        try? await Task.sleep(for: .milliseconds(600))
                    }
                    look = .done("Done · Store Page · German")
                    doneCount += 1
                    try? await Task.sleep(for: AutopilotButtonLook.doneDuration)
                    look = .idle
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }
}
#endif
