//
//  AnalyticsSegments.swift
//  Atlas
//

import SwiftUI

/// A small segmented control whose segments can carry a neutral count:
/// Analytics' views, periods, dimensions and filters.
struct AnalyticsSegments<Value: Hashable>: View {
    let label: String
    let options: [(value: Value, title: String, count: Int)]
    @Binding var selection: Value
    /// The accessibility identifier's prefix; each segment adds its index.
    var identifier: String?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.element.value) { index, option in
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: Spacing.xSmall) {
                        Text(option.title)
                        if option.count > 0 { NeutralCountPill(count: option.count) }
                    }
                    .font(.subheadline.weight(selection == option.value ? .medium : .regular))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 22)
                    .background {
                        if selection == option.value {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Palette.raised)
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.count > 0 ? String(localized: "\(option.title), \(option.count) new") : option.title))
                .accessibilityAddTraits(selection == option.value ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(identifier.map { "\($0).\(index)" } ?? "")
            }
        }
        .padding(2)
        .background(Palette.fill2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }
}

extension AnalyticsSegments {
    /// Without counts.
    init(label: String, plain options: [(value: Value, title: String)], selection: Binding<Value>, identifier: String? = nil) {
        self.init(label: label, options: options.map { ($0.value, $0.title, 0) }, selection: selection, identifier: identifier)
    }
}
