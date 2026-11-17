//
//  RadioRow.swift
//  Atlas
//

import SwiftUI

/// One choice of a short list: a radio button, a title and an optional
/// line under it. The whole row is the button.
struct RadioRow<Leading: View>: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    var isDisabled = false
    let action: () -> Void
    /// Between the radio and the title, e.g. a build number in digits.
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Palette.accent : Palette.label3)
                    .accessibilityHidden(true)
                leading()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension RadioRow where Leading == EmptyView {
    init(title: String, detail: String? = nil, isSelected: Bool, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, detail: detail, isSelected: isSelected, isDisabled: isDisabled, action: action) { EmptyView() }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        RadioRow(title: "Release right after approval", isSelected: false) {}
        RadioRow(title: "I’ll release it myself", detail: "Atlas tells you when it’s approved.", isSelected: true) {}
    }
    .frame(width: 320)
    .padding()
}
