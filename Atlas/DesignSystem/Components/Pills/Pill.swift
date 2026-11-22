//
//  Pill.swift
//  Atlas
//

import SwiftUI

/// A small capsule label: status badges, counts, coverage states. On a
/// selected table row it switches to white on 20% white, since custom
/// backgrounds inside rows don't invert by themselves.
struct Pill: View {
    let text: String
    var systemImage: String?
    var style: PillStyle = .neutral
    /// Bigger text for cards and sheets; tables use the default.
    var isProminent = false

    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(text)
                .monospacedDigit()
                .lineLimit(1)
        }
        // A state pill (README — Design system §5): 20 pt, 11 pt semibold.
        .font(isProminent ? .callout.weight(.medium) : .subheadline.weight(.semibold))
        .foregroundStyle(onSelection ? Color.white : style.foreground)
        .padding(.horizontal, isProminent ? 8 : 7)
        .padding(.vertical, isProminent ? 2 : 0)
        .frame(minHeight: isProminent ? nil : 20)
        .background(onSelection ? Color.white.opacity(0.2) : style.background, in: Capsule())
        .overlay {
            if let border = style.border(increasedContrast: contrast == .increased), !onSelection {
                Capsule().strokeBorder(border, lineWidth: contrast == .increased ? 1 : 0.5)
            }
        }
    }

    private var onSelection: Bool { prominence == .increased }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Pill(text: "Base")
        Pill(text: "Missing", style: .outline)
        Pill(text: "31/30", systemImage: "exclamationmark.triangle.fill", style: .danger)
        Pill(text: "MT", systemImage: "sparkles", style: .machineTranslated)
        Pill(text: "Edited", style: .accent)
        Pill(text: "Older than a year", style: .warning, isProminent: true)
    }
    .padding()
}
