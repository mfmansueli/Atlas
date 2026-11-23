//
//  PushProgressRowLayout.swift
//  Atlas
//

import SwiftUI

/// The row every part of a push shares (a change, a screenshot, an extra,
/// an event's art): its state, a thumbnail when it sends an image or a
/// video (a click opens it large over the sheet), its title with what it's
/// doing or why it failed underneath, and its step on the right, with a
/// bar while it uploads. The thumbnail column is kept in every row when
/// any has one, so the titles line up.
struct PushProgressRowLayout<Thumbnail: View>: View {
    let state: PushProgressState
    var isConflict = false
    let title: Text
    /// What it's doing, or why it didn't go (red when it failed).
    let detail: String?
    let trailing: String
    /// The upload's share sent, for the bar under the step.
    var fraction: Double?
    /// The width of the thumbnail column; nil when no row has one.
    let thumbnailWidth: CGFloat?
    let accessibilityText: String
    let identifier: String
    /// Opens the thumbnail large; nil without one.
    var onOpen: (() -> Void)?
    @ViewBuilder let thumbnail: () -> Thumbnail

    var body: some View {
        HStack(spacing: 10) {
            PushStatusIcon(state: state, isConflict: isConflict)
            if let thumbnailWidth {
                thumbnailButton
                    .frame(width: thumbnailWidth)
            }
            HStack(spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(state.failureReason != nil ? Palette.err : Palette.label2)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(trailing)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .monospacedDigit()
                        .lineLimit(1)
                    if let fraction {
                        ProgressView(value: min(1, max(0, fraction)))
                            .progressViewStyle(.linear)
                            .controlSize(.mini)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 200, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityText))
            .accessibilityIdentifier(identifier)
        }
        .font(.callout)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var thumbnailButton: some View {
        if let onOpen {
            Button(action: onOpen) {
                thumbnail()
            }
            .buttonStyle(.plain)
            .help(String(localized: "Click to see it larger"))
            .accessibilityLabel(Text("Show it larger"))
            .accessibilityIdentifier("\(identifier).open")
        } else {
            thumbnail()
        }
    }
}

extension PushProgressRowLayout where Thumbnail == EmptyView {
    /// A row with nothing to show large: its thumbnail column stays empty.
    init(
        state: PushProgressState, isConflict: Bool = false, title: Text, detail: String?, trailing: String, fraction: Double? = nil,
        thumbnailWidth: CGFloat?, accessibilityText: String, identifier: String
    ) {
        self.init(
            state: state, isConflict: isConflict, title: title, detail: detail, trailing: trailing, fraction: fraction,
            thumbnailWidth: thumbnailWidth, accessibilityText: accessibilityText, identifier: identifier, onOpen: nil
        ) { EmptyView() }
    }
}
