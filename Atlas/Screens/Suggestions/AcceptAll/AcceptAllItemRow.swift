//
//  AcceptAllItemRow.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// One suggestion on the sheet's right side: its checkbox, the field, who
/// suggested it, Now and New, and why; a caption's screenshot before →
/// after at the end. Dimmed once unticked.
struct AcceptAllItemRow: View {
    let item: AcceptAllItem
    let isSelected: Bool
    let isRightToLeft: Bool
    /// The capture a caption's screenshot draws; nil draws none.
    let captureImage: (@MainActor (SlotPreview) -> CGImage?)?
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AcceptAllCheckbox(state: isSelected ? .checked : .unchecked, label: String(localized: "Accept \(item.title)"), action: onToggle)
                .accessibilityIdentifier("acceptAll.item.\(item.id)")
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xSmall) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let sounds = item.sounds {
                        Pill(text: sounds.word, style: sounds.pillStyle)
                            .fixedSize()
                            .accessibilityIdentifier("acceptAll.item.sounds")
                    }
                    SuggestionSourceTag(source: item.source)
                }
                values
                    .opacity(isSelected ? 1 : 0.5)
                if let reason = item.soundsOffReason {
                    Text(reason)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.warn)
                        .fixedSize(horizontal: false, vertical: true)
                        .environment(\.layoutDirection, .leftToRight)
                        .accessibilityIdentifier("acceptAll.item.soundsOff")
                }
                Text(item.reason)
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let screenshot = item.screenshot, let captureImage {
                AcceptAllShotPair(screenshot: screenshot, captureImage: captureImage)
                    .opacity(isSelected ? 1 : 0.5)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(isSelected ? AnyShapeStyle(Palette.aiSurface) : AnyShapeStyle(Palette.fill1), in: shape)
        .overlay(shape.strokeBorder(isSelected ? Palette.aiMark.opacity(0.35) : Palette.separator, lineWidth: isSelected ? 1 : 0.5))
        .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    private var values: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 3) {
            GridRow {
                Text("Now")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .gridColumnAlignment(.leading)
                value(item.current.isEmpty ? String(localized: "Empty") : item.current, isRightToLeft: isRightToLeft && !item.current.isEmpty)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(3)
            }
            GridRow {
                Text("New")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                value(item.suggested, isRightToLeft: isRightToLeft)
                    .lineLimit(6)
            }
            if let means = item.means {
                GridRow {
                    TranslationMeansLabel()
                    TranslationMeansText(means: means)
                        .lineLimit(4)
                }
            }
        }
    }

    private func value(_ text: String, isRightToLeft: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

#Preview {
    AcceptAllItemRow(
        item: AcceptAllItem(
            id: "1",
            title: "Subtitle",
            source: .assistant(client: "Claude Code"),
            current: "Mood journal & prompts",
            suggested: "Private diary, mood & prompts",
            reason: "“Private” is the word people praise most in your last 220 reviews."
        ),
        isSelected: true,
        isRightToLeft: false,
        captureImage: nil
    ) {}
        .padding()
        .frame(width: 520)
}
