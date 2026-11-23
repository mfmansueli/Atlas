//
//  OfferCodeCodesList.swift
//  Atlas
//

import SwiftUI

/// An offer code's custom codes and batches of one-time codes, each with
/// what it is, Save Codes… (one-time codes) and Deactivate….
struct OfferCodeCodesList: View {
    let code: ExistingOfferCode
    let onSave: (ExistingOneTimeCodes) -> Void
    let onDeactivate: (OfferCodeChangeBuilder.Target) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.identifier) { index, line in
                row(line, isFirst: index == 0)
            }
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.offerCodes")
    }

    /// One custom code or batch.
    private struct Line {
        var title: String
        var detail: String
        var isActive: Bool
        var identifier: String
        var target: OfferCodeChangeBuilder.Target
        var batch: ExistingOneTimeCodes?
    }

    private var lines: [Line] {
        code.customCodes.map { custom in
            Line(
                title: custom.code, detail: custom.summary, isActive: custom.isActive,
                identifier: "pricing.offerCodes.custom.\(custom.id)", target: .customCode(custom)
            )
        } + code.oneTimeCodes.map { batch in
            Line(
                title: String(localized: "One-time codes"), detail: batch.summary, isActive: batch.isActive,
                identifier: "pricing.offerCodes.batch.\(batch.id)", target: .oneTimeCodes(batch), batch: batch
            )
        }
    }

    private func row(_ line: Line, isFirst: Bool) -> some View {
        let (title, detail, isActive, identifier) = (line.title, line.detail, line.isActive, line.identifier)
        return VStack(spacing: 0) {
            if !isFirst { Divider() }
            HStack(spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .fontWeight(.semibold)
                        .monospaced(title == title.uppercased())
                    Text(isActive ? detail : String(localized: "\(detail) · deactivated"))
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: Spacing.small)
                if let batch = line.batch {
                    Button("Save Codes…") { onSave(batch) }
                        .accessibilityIdentifier("\(identifier).save")
                }
                if isActive, code.isActive {
                    Button("Deactivate…", role: .destructive) { onDeactivate(line.target) }
                        .accessibilityIdentifier("\(identifier).deactivate")
                }
            }
            .controlSize(.regular)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
