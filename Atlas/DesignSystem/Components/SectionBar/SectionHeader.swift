//
//  SectionHeader.swift
//  Atlas
//

import SwiftUI

/// The top of a section's page, under the toolbar that names it (board
/// 57, board 88): one sentence about what it changes on the App Store,
/// and the page's own controls on the right. Under the sentence a second
/// line: the page's `detail` when given (App Information's "19
/// suggestions · about 10 min", Analytics' range and "Data through Nov
/// 9"), else the section's summary line when something waits
/// (`\.sectionSummary`). The section's title and state are in the
/// toolbar, not here.
struct SectionHeader<Detail: View, Trailing: View>: View {
    let subtitle: String
    @ViewBuilder var detail: () -> Detail
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("section.description")
                if Detail.self == EmptyView.self {
                    SectionSummaryLine()
                } else {
                    detail()
                }
            }
            Spacer(minLength: Spacing.small)
            HStack(spacing: Spacing.small) {
                trailing()
            }
            .fixedSize()
        }
        .frame(minHeight: 32)
    }
}

extension SectionHeader where Detail == EmptyView {
    /// The sentence over the section's summary line.
    init(subtitle: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(subtitle: subtitle, detail: { EmptyView() }, trailing: trailing)
    }
}

#Preview {
    SectionHeader(subtitle: "The words on Lumen’s App Store page and in search, in every language.") {
        Button("Translate Missing…") {}
    }
    .padding()
    .frame(width: 720)
}
