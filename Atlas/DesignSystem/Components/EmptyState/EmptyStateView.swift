//
//  EmptyStateView.swift
//  Atlas
//

import SwiftUI

/// The one empty state (README-DS §14, board 74), a
/// `ContentUnavailableView`: the section's symbol (the sidebar's, in
/// tertiary label), a title ("No nominations yet"), one or two sentences on
/// what the thing is and how to start, naming the top button and the
/// assistant's, and an optional small line with what to expect.
///
/// The create button stays at the top of the section, full or empty, so
/// `actions` is only for what exists nowhere else on screen: Add
/// Screenshots…, Check Now, Show All Reviews, Clear Search. A page's empty
/// state is centred a little above the middle; `.inline` is the smaller
/// one where a list's rows would be.
struct EmptyStateView<Actions: View>: View {
    let title: String
    let systemImage: String
    var text: String?
    var note: String?
    var size: EmptyStateSize = .page
    @ViewBuilder let actions: () -> Actions

    init(
        _ title: String,
        systemImage: String,
        text: String? = nil,
        note: String? = nil,
        size: EmptyStateSize = .page,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.text = text
        self.note = note
        self.size = size
        self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .atlasTextStyle(size.titleStyle)
                    .foregroundStyle(Palette.label)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: size.symbolSize))
                    .foregroundStyle(Palette.label3)
                    .accessibilityHidden(true)
            }
        } description: {
            VStack(spacing: Spacing.medium) {
                if let text {
                    Text(text)
                        .atlasTextStyle(.body)
                        .foregroundStyle(Palette.label2)
                }
                if let note {
                    Text(note)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label3)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: Metrics.emptyStateTextWidth)
        } actions: {
            actions()
        }
        .padding(.top, size.topInset)
        .padding(.bottom, size.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: size == .page ? .infinity : nil)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyStateView where Actions == EmptyView {
    /// An empty state with nothing to do but read it: the create button
    /// is at the top of the section, or there's nothing to do yet.
    init(_ title: String, systemImage: String, text: String? = nil, note: String? = nil, size: EmptyStateSize = .page) {
        self.init(title, systemImage: systemImage, text: text, note: note, size: size) { EmptyView() }
    }
}
