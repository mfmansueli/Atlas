//
//  PageShotsMakingStep.swift
//  Atlas
//

import SwiftUI

/// Making: one bar, one sentence, and the screenshots loading one by one,
/// the primary language first. Stop goes back to Plan; Hide · Keeps Going
/// closes the sheet and Autopilot goes on. While the assistant changes the
/// set (Ask for Changes), it says what was asked.
struct PageShotsMakingStep: View {
    @Bindable var flow: PageShotsFlow
    let source: PageShotsSource

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.large) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    ProgressView(value: isRevising ? nil : flow.progress)
                        .progressViewStyle(.linear)
                        .accessibilityLabel(Text("Screenshots ready"))
                        .accessibilityIdentifier("pages.shots.progress")
                    Text(headline)
                        .font(.headline)
                        .monospacedDigit()
                        .accessibilityIdentifier("pages.shots.progressText")
                }
                if isRevising, let change = flow.run?.changeRequest {
                    Text("You asked: “\(change)”")
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pages.shots.changeAsked")
                }
                tiles
                Spacer(minLength: 0)
                Text("Close this window whenever you like. Autopilot keeps going, and the page shows it.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            HStack(spacing: Spacing.medium) {
                Spacer()
                Button("Stop") { flow.stopMaking() }
                    .disabled(isRevising)
                    .accessibilityIdentifier("pages.shots.stop")
                Button("Hide · Keeps Going") { flow.hide() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pages.shots.hide")
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
    }

    private var isRevising: Bool { flow.run?.stage == .revising }

    private var headline: String {
        if isRevising {
            let assistant = flow.run?.plan?.source ?? "Claude Code"
            return String(localized: "\(assistant) is changing the set")
        }
        return flow.progressText
    }

    /// The primary language's screenshots on the first device, made or
    /// still to come.
    private var tiles: some View {
        let run = flow.run
        let locale = run?.primaryLocale ?? source.primary
        let display = run?.displays.first ?? .iPhone
        let count = run?.plan?.screens.count ?? 0
        let height: CGFloat = display == .iPad ? 180 : 236
        return ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                ForEach(0..<count, id: \.self) { position in
                    let image = run?.image(locale: locale, displayType: display, position: position)
                    VStack(spacing: 3) {
                        if let image, let run {
                            PageShotsTile(
                                url: flow.studio.url(of: image, in: run), aspect: PageShotsTile.aspect(display), height: height,
                                overflows: !image.fits, label: String(localized: "Screenshot \(position + 1)")
                            )
                        } else {
                            ImageLoadingTile(isLoading: run?.stage == .making)
                                .frame(width: height * PageShotsTile.aspect(display), height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        Text(image == nil ? String(localized: "Laying out…") : ProductPageChangeBuilder.localeName(locale))
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pages.shots.making.\(position + 1)")
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
