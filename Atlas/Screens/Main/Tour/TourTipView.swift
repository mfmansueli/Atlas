//
//  TourTipView.swift
//  Atlas
//

import SwiftUI

/// One tip of the tour, in its popover: the tip's glyph on a tinted tile,
/// its title and text, then Next (Done on the last) and Skip the Tour
/// (Connect an Assistant… on the last) beside "1 of 5", and a close button
/// in the corner.
struct TourTipView: View {
    let step: TourStep
    let onNext: () -> Void
    let onAlternative: () -> Void
    let onClose: () -> Void

    @State private var isCloseHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.accentText)
                .frame(width: 30, height: 30)
                .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 18)
                    .accessibilityIdentifier("tour.title")
                Text(step.text)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tour.text")
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 12)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .frame(width: 320)
        .overlay(alignment: .topTrailing) { closeButton }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Tip \(step.countText)"))
        .accessibilityIdentifier("tour.tip.\(step.number)")
    }

    private var actions: some View {
        HStack(spacing: 14) {
            Button(step.nextTitle, action: onNext)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("tour.next")
            Button(step.alternativeTitle, action: onAlternative)
                .accessibilityIdentifier("tour.alternative")
            Spacer(minLength: 0)
            Text(step.countText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("tour.count")
        }
        .buttonStyle(TourTipButtonStyle())
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.separator)
                .frame(height: 0.5)
        }
        .padding(.top, 7)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .frame(width: 22, height: 22)
                .background(isCloseHovered ? Palette.fill2 : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovered = $0 }
        .help("Close the tour")
        .accessibilityLabel(Text("Close the tour"))
        .accessibilityIdentifier("tour.close")
        .padding(8)
    }
}

#Preview {
    VStack(spacing: 20) {
        TourTipView(step: .apps, onNext: {}, onAlternative: {}, onClose: {})
        TourTipView(step: .settings, onNext: {}, onAlternative: {}, onClose: {})
    }
    .padding()
}
