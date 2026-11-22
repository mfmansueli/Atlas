//
//  AppSwitcherRow.swift
//  Atlas
//

import SwiftUI

/// One app in the app menu: icon, name and bundle ID, a dot for unpushed
/// changes, the purple count of suggestions to review, a check on the
/// app being viewed, and a PRO chip on the apps Free doesn't open.
struct AppSwitcherRow: View {
    let app: StoreApp
    var indicators = AppIndicators()
    let isCurrent: Bool
    /// In Free, an app other than the free one: choosing it opens the
    /// paywall.
    var isLocked = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                AppIconTile(name: app.name, icon: app.icon, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        if indicators.hasUnpushedChanges {
                            UnsavedDot(size: 7)
                        }
                        Text(app.name)
                            .lineLimit(1)
                    }
                    Text(app.bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionBadge(count: indicators.suggestionCount)
                if isLocked {
                    ProChip()
                }
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.label2)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.small)
            .frame(height: 40)
            .background(isCurrent ? Palette.fill3 : (isHovered ? Palette.fill1 : .clear), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(app.name))
        .accessibilityValue(isLocked ? Text("Needs Atlas Pro") : suggestionText)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    /// "12 suggestions to review"; nothing without any.
    private var suggestionText: Text {
        switch indicators.suggestionCount {
        case 0: Text(verbatim: "")
        case 1: Text("1 suggestion to review")
        default: Text("\(indicators.suggestionCount) suggestions to review")
        }
    }
}
