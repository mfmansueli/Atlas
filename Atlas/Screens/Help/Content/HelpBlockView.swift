//
//  HelpBlockView.swift
//  Atlas
//

import SwiftUI

/// One block of a Help article, with its **bold** words.
struct HelpBlockView: View {
    let block: HelpBlock

    var body: some View {
        switch block {
        case let .paragraph(text):
            styled(text)
        case let .heading(text):
            Text(text)
                .font(.title3.weight(.semibold))
                .padding(.top, Spacing.xSmall)
                .accessibilityAddTraits(.isHeader)
                .id(HelpBlock.anchor(for: text))
        case let .steps(items):
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Text("\(index + 1)")
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .frame(width: 22, height: 22)
                            .background(Palette.fill2, in: Circle())
                        styled(item)
                    }
                }
            }
        case let .bullets(items):
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Text("•")
                            .foregroundStyle(Palette.label2)
                        styled(item)
                    }
                }
            }
        case let .note(text):
            styled(text)
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field))
                .accessibilityIdentifier("help.note")
        case let .table(header, rows):
            HelpTableView(header: header, rows: rows)
        }
    }

    private func styled(_ text: String) -> some View {
        Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
