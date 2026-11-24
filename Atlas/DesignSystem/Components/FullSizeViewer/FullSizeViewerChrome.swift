//
//  FullSizeViewerChrome.swift
//  Atlas
//

import SwiftUI

/// A full-size viewer's frame, Quick Look–style, over whatever it covers:
/// the item's name and what else says what it is, an optional control,
/// "2 of 5", previous and next (or the arrow keys), Close or Esc, and Space for
/// the item (play or pause a movie, close a still). `content` gets the
/// room between the arrows. Identifiers start with `identifier`
/// (`studio.viewer`, `review.viewer`).
struct FullSizeViewerChrome<Accessory: View, Content: View>: View {
    let identifier: String
    let title: String
    let subtitle: String
    let countTitle: String?
    let hasPrevious: Bool
    let hasNext: Bool
    let onStep: (Int) -> Void
    let onClose: () -> Void
    let onSpace: () -> Void
    /// ↑ (-1) and ↓ (1), when the viewer has a use for them.
    var onVerticalStep: ((Int) -> Void)?
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: (CGSize) -> Content

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: Spacing.medium) {
                Button { onStep(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(RoundButtonStyle())
                    .disabled(!hasPrevious)
                    .help(Text("Previous (←)"))
                    .accessibilityLabel(Text("Previous"))
                    .accessibilityIdentifier("\(identifier).previous")
                GeometryReader { proxy in
                    content(proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                Button { onStep(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(RoundButtonStyle())
                    .disabled(!hasNext)
                    .help(Text("Next (→)"))
                    .accessibilityLabel(Text("Next"))
                    .accessibilityIdentifier("\(identifier).next")
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Palette.viewerStage.opacity(0.88)
            }
            .contentShape(Rectangle())
            .onTapGesture { onClose() }
        }
        .environment(\.colorScheme, .dark)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.leftArrow) {
            onStep(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            onStep(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard let onVerticalStep else { return .ignored }
            onVerticalStep(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard let onVerticalStep else { return .ignored }
            onVerticalStep(1)
            return .handled
        }
        .onKeyPress(.space) {
            onSpace()
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onExitCommand { onClose() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
    }

    private var header: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .accessibilityIdentifier("\(identifier).title")
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .accessibilityIdentifier("\(identifier).subtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory()
            if let countTitle {
                Text(countTitle)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityIdentifier("\(identifier).count")
            }
            Button { onClose() } label: { Image(systemName: "xmark") }
                .buttonStyle(RoundButtonStyle())
                .help(Text("Close (Esc)"))
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("\(identifier).close")
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
    }

    /// The viewer's round buttons: white on a light glass circle.
    private struct RoundButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.35))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white.opacity(configuration.isPressed ? 0.28 : 0.16)))
                .contentShape(Circle())
        }
    }
}
