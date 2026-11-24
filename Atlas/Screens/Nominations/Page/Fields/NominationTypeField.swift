//
//  NominationTypeField.swift
//  Atlas
//

import SwiftUI

/// Type: three options with one line each, side by side (stacked in the
/// small window). Atlas's suggested option is marked in purple.
struct NominationTypeField: View {
    let selection: NominationType?
    var suggested: NominationType?
    var isCompact = false
    let onPick: (NominationType) -> Void

    var body: some View {
        let layout = isCompact ? AnyLayout(VStackLayout(spacing: Spacing.small)) : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.small))
        layout {
            ForEach(NominationType.allCases) { type in
                option(type)
            }
        }
    }

    private func option(_ type: NominationType) -> some View {
        let isOn = selection == type
        let isSuggested = suggested == type && !isOn
        return Button {
            onPick(type)
        } label: {
            HStack(alignment: .top, spacing: Spacing.small) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isOn ? Palette.accent : Palette.label3)
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Label(type.title, systemImage: type.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.label)
                    Text(type.line)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? Palette.accentTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(isOn ? Palette.accent : isSuggested ? Palette.aiEdge : Palette.separator, lineWidth: isOn || isSuggested ? 1 : 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(type.title). \(type.line)"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("nominations.type.\(type.rawValue)")
    }
}
