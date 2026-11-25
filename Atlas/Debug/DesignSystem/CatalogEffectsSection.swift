//
//  CatalogEffectsSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The five AI effects of motion v2 (README — Design system §7, board 68)
/// playing with the real modifiers: Trail, Working, Arrived, Accepted ·
/// Dismissed · Undone, and Needs you. They play again every few seconds
/// and on Play Again; the catalog's Reduce Motion shows their still
/// versions.
struct CatalogEffectsSection: View {
    @State private var replay = 0

    /// How often the effects play by themselves.
    static let cycle: Duration = .seconds(5)

    var body: some View {
        CatalogSection(
            title: "AI motion · the five effects",
            note: "Motion belongs to the assistant: gently and once. At most one loop on screen, the progress sweep."
        ) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Button("Play Again") { replay += 1 }
                    .accessibilityIdentifier("designSystem.catalog.playAgain")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: Spacing.large, alignment: .top)], alignment: .leading, spacing: Spacing.large) {
                    tile("1 · Trail", "The spark travels button → Autopilot → the place of the work, 0.7 s per leg.") { TrailDemo() }
                    tile("2 · Working", "The spark sits still; a bar only with units, in steps, with a soft sweep. The chat's ✦ breathes.") { WorkingDemo() }
                    tile("3 · Arrived", "Tint fades in; text word by word with a caret; images develop; lists 70 ms apart.") { ArrivedDemo() }
                    tile("4 · Accepted · Dismissed · Undone", "Accept goes neutral with a check; dismiss closes; undo slides down 6 pt.") { DecidedDemo() }
                    tile("5 · Needs you", "One nudge, then still. A failure is amber and slides in 4 pt.") { NeedsYouDemo() }
                }
                .id(replay)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.cycle)
                replay += 1
            }
        }
    }

    private func tile(_ title: String, _ note: String, @ViewBuilder demo makeDemo: () -> some View) -> some View {
        let demo = makeDemo()
        return Card {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(title).atlasTextStyle(.title3)
                Text(note)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                demo
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            }
        }
    }

    // MARK: - 1 · Trail

    private struct TrailDemo: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var start = Date.now

        var body: some View {
            GeometryReader { proxy in
                let size = proxy.size
                let button = CGPoint(x: 70, y: size.height - 18)
                let autopilot = CGPoint(x: size.width - 60, y: 16)
                let place = CGPoint(x: size.width / 2, y: size.height / 2)
                ZStack(alignment: .topLeading) {
                    label("Suggest Texts…", at: button)
                    label("Autopilot", at: autopilot)
                    label("Subtitle", at: place)
                    if reduceMotion {
                        // No travel: the spark appears still at the place.
                        AISpark().position(x: place.x + 46, y: place.y)
                    } else {
                        TrailView(path: TrailPath(from: button, via: autopilot, to: place), start: start)
                    }
                }
            }
            .frame(height: 150)
        }

        private func label(_ text: String, at point: CGPoint) -> some View {
            Text(text)
                .atlasTextStyle(.subheadline)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxSmall)
                .background(Palette.fill2, in: Capsule())
                .position(point)
        }
    }

    // MARK: - 2 · Working

    private struct WorkingDemo: View {
        @State private var few = AIProgress(done: 0, total: 3)
        @State private var many = AIProgress(done: 90, total: 255)
        @State private var isWorking = true

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                bar(few)
                bar(many)
                AIWorkingStep(text: "Reading the project…")
                // The chat button: the ✦ breathes and the step's text sweeps.
                HStack(spacing: Spacing.small) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Palette.ai)
                        .aiBreathing(isWorking)
                    Text("Reading 220 reviews…")
                        .atlasTextStyle(.body)
                        .aiSweep(isWorking)
                }
                Text("Lumen Plus Annual")
                    .atlasTextStyle(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .padding(.horizontal, Spacing.medium)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .aiWorking(isWorking)
            }
            .task {
                for step in 1...3 {
                    try? await Task.sleep(for: .milliseconds(900))
                    few = AIProgress(done: step, total: 3)
                    many = AIProgress(done: 90 + step * 3, total: 255)
                }
                isWorking = false
            }
        }

        private func bar(_ progress: AIProgress) -> some View {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(progress.line(elapsed: Double(progress.done) * 3))
                    .atlasTextStyle(.subheadline)
                    .monospacedDigit()
                AIProgressBar(value: progress.fraction, isWorking: progress.done < progress.total)
            }
        }
    }

    // MARK: - 3 · Arrived

    private struct ArrivedDemo: View {
        @State private var arrivedAt = Date.now
        @State private var count = 2
        private let key = UUID().uuidString

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    Text("Store Page").atlasTextStyle(.body)
                    SuggestionBadge(count: count)
                        .modifier(CountTick(count: count, scope: "catalog"))
                }
                ArrivingText("Deine Woche auf einer ruhigen Seite, jeden Sonntag")
                    .atlasTextStyle(.callout)
                HStack(spacing: Spacing.small) {
                    Palette.sectionEvents
                        .frame(width: 64, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                        .aiArrivedImage(key: "\(key).image", arrivedAt: arrivedAt)
                    VStack(alignment: .leading, spacing: Spacing.tiny) {
                        ForEach(0..<4, id: \.self) { index in
                            Text("Subtitle · language \(index + 1)")
                                .atlasTextStyle(.subheadline)
                                .padding(.horizontal, Spacing.xSmall)
                                .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
                                .aiArrived(key: "\(key).\(index)", arrivedAt: arrivedAt)
                        }
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(2.2))
                count += 1
            }
        }
    }

    // MARK: - 4 · Accepted · Dismissed · Undone

    private struct DecidedDemo: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isSettling = false
        @State private var isAcceptedShown = true
        @State private var isDismissedShown = true

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.small) {
                if isAcceptedShown {
                    card("Accept · goes neutral with a check")
                        .suggestionSurface(isSettling: isSettling, arrivalKey: "catalog.accept", arrivedAt: nil)
                } else {
                    HStack(spacing: Spacing.xSmall) {
                        Text("Subtitle").atlasTextStyle(.headline)
                        Pill(text: "Not pushed", systemImage: "circle.fill", style: .accent)
                    }
                }
                if isDismissedShown {
                    card("Dismiss · drains and closes")
                        .suggestionSurface(isSettling: false, arrivalKey: "catalog.dismiss", arrivedAt: nil)
                }
                Text("Below moves up").atlasTextStyle(.subheadline).foregroundStyle(Palette.label2)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(700))
                AIDecided.accept(reduceMotion: reduceMotion, settle: { isSettling = true }, commit: { isAcceptedShown = false })
                try? await Task.sleep(for: .milliseconds(900))
                AIDecided.dismiss(reduceMotion: reduceMotion) { isDismissedShown = false }
                try? await Task.sleep(for: .milliseconds(1400))
                AIDecided.undo(reduceMotion: reduceMotion) {
                    isSettling = false
                    isAcceptedShown = true
                    isDismissedShown = true
                }
            }
        }

        private func card(_ text: String) -> some View {
            Text(text)
                .atlasTextStyle(.callout)
                .padding(Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 5 · Needs you

    private struct NeedsYouDemo: View {
        @State private var look: AutopilotButtonLook = .working("Capturing Annual · 2 of 3", progress: 2.0 / 3)
        @State private var failure: String?

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                AutopilotButtonFace(
                    look: look, title: "Make Screenshots…", accessibilityLabel: look.text ?? "",
                    onMain: {}, menu: { Button("Show Run…") {} }
                )
                .fixedSize()
                ZStack(alignment: .topLeading) {
                    if failure != nil {
                        Label("Claude Code couldn’t find the paywall. Say where it is, then Try Again.", systemImage: "exclamationmark.triangle.fill")
                            .atlasTextStyle(.callout)
                            .padding(Spacing.small)
                            .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                    }
                }
                .aiFailureArrival(key: failure)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(800))
                look = .needsYou("Show It the Paywall")
                try? await Task.sleep(for: .milliseconds(1200))
                failure = "paywall"
            }
        }
    }
}
#endif
