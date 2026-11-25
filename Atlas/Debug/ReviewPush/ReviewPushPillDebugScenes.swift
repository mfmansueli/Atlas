//
//  ReviewPushPillDebugScenes.swift
//  Atlas
//

#if DEBUG
import Foundation
import SwiftUI
import Synchronization

/// Review & Push at the bottom (board 80), in the main window:
///
/// - `bar-pend`: Store Page with German What's New and Keywords accepted:
///   blue, with the count.
/// - `bar-fly`: German What's New just accepted: its chip held still
///   mid-air on its way to Review & Push.
/// - `bar-push`: Overview while a push runs minimized: “Pushing · 14 of
///   23”.
/// - `bar-pills`: every look of the pill on its own, at the bottom of an
///   empty page, folded and not.
enum ReviewPushPillDebugScenes {
    static let ids = ["bar-pend", "bar-fly", "bar-push", "bar-pills"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "bar-pend":
            AnyView(DebugMainScene(section: .storePage, pendingChanges: [whatsNew, keywords]))
        case "bar-fly":
            AnyView(Flying())
        case "bar-push":
            AnyView(pushing)
        case "bar-pills":
            AnyView(Pills())
        default:
            nil
        }
    }

    // MARK: - Scenes

    /// 23 of Lumen's annual prices on their way, the push held after 14.
    @MainActor
    private static var pushing: some View {
        var services = WorkspaceServices.debug
        services.push = HoldingPushTransport(answering: 14)
        return DebugMainScene(
            services: services,
            section: .overview,
            pendingChanges: Array(DebugReviewData.annualPriceChanges.prefix(23)),
            autoPush: true
        )
    }

    /// German What's New accepted; once the window shows, its chip waits
    /// in the air where the board draws it, between the click and the pill.
    private struct Flying: View {
        var body: some View {
            DebugMainScene(section: .storePage, pendingChanges: [ReviewPushPillDebugScenes.whatsNew])
                .task {
                    try? await Task.sleep(for: .seconds(1.5))
                    let center = PushFlightCenter.shared
                    guard let window = center.targetWindow?.frame else { return }
                    // Where the board's click is: 520, 430 in its 1200 × 780 window.
                    let click = CGPoint(x: window.minX + window.width * 0.433, y: window.maxY - window.height * 0.551)
                    center.showFrozen(label: "What’s New · German", from: click, at: MotionTiming.sentLift.duration + 0.3)
                }
        }
    }

    /// Each state of the pill in a bottom row, as the bar's dock places it.
    private struct Pills: View {
        private let states: [(String, ReviewPushPillState)] = [
            ("Up to Date", .upToDate),
            ("Changes waiting", .pending(2)),
            ("Pushing", .pushing(sent: 14, total: 23)),
        ]

        var body: some View {
            VStack(alignment: .trailing, spacing: Spacing.xLarge) {
                ForEach(states, id: \.0) { name, state in
                    HStack(alignment: .bottom, spacing: Spacing.small) {
                        Text(name).foregroundStyle(Palette.label2)
                        Spacer(minLength: 0)
                        ReviewPushPillFace(state: state, isCompact: true) {}
                        ReviewPushPillFace(state: state) {}
                    }
                }
            }
            .padding(Spacing.xxLarge)
            .frame(minWidth: 640, minHeight: 320, alignment: .bottom)
            .background(Palette.content)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reviewPushPill.gallery")
        }
    }

    // MARK: - Data

    static let whatsNew = listingChange(field: "What’s New", new: "• Neu: Wochenrückblicke\n• Schnellere Suche")
    static let keywords = listingChange(field: "Keywords", new: "tagebuch,journal,achtsamkeit,ruhe")

    /// German, accepted from a built-in suggestion.
    private static func listingChange(field: String, new: String) -> PendingChange {
        let path = "/v1/appStoreVersionLocalizations/debug-lumen-DE"
        return PendingChange(
            id: "listing.debug-lumen-14.German.\(field)",
            appID: DebugFixtures.AppID.lumen,
            section: .storePage,
            group: DebugReviewData.versionGroup,
            title: "German · \(field)",
            flagRegion: "DE",
            oldValue: "",
            newValue: new,
            source: .builtInSuggestion,
            requests: [PushRequest(method: .patch, path: path, body: Data("{\"field\":\"\(field)\"}".utf8))]
        )
    }

    /// Answers the first `answering` requests, then holds the rest, so a
    /// push stays part-way.
    private final class HoldingPushTransport: PushTransport {
        private let answering: Int
        private let base = DebugPushTransport(delay: .milliseconds(40))
        private let sent = Mutex(0)

        init(answering: Int) {
            self.answering = answering
        }

        func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
            let index = sent.withLock { value in
                value += 1
                return value
            }
            if index > answering { try await Task.sleep(for: .seconds(3600)) }
            return try await base.send(request)
        }

        func fetch(_ path: String) async throws -> AppStoreConnectResponse {
            try await base.fetch(path)
        }
    }
}
#endif
