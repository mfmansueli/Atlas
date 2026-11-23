//
//  OfferCodeCodesList.swift
//  Atlas
//

import SwiftUI

/// An offer code's custom codes and batches of one-time codes (a
/// subscription's or an in-app purchase's), each with what it is, Save
/// Codes… (one-time codes) and Deactivate….
struct OfferCodeCodesList: View {
    let customCodes: [ExistingCustomCode]
    let oneTimeCodes: [ExistingOneTimeCodes]
    /// Whether the offer code itself is active: an inactive one's codes
    /// can't be deactivated.
    let isActive: Bool
    let onSave: (ExistingOneTimeCodes) -> Void
    let onDeactivate: (OfferCodeChangeBuilder.Target) -> Void

    init(
        customCodes: [ExistingCustomCode], oneTimeCodes: [ExistingOneTimeCodes], isActive: Bool,
        onSave: @escaping (ExistingOneTimeCodes) -> Void, onDeactivate: @escaping (OfferCodeChangeBuilder.Target) -> Void
    ) {
        self.customCodes = customCodes
        self.oneTimeCodes = oneTimeCodes
        self.isActive = isActive
        self.onSave = onSave
        self.onDeactivate = onDeactivate
    }

    init(code: ExistingOfferCode, onSave: @escaping (ExistingOneTimeCodes) -> Void, onDeactivate: @escaping (OfferCodeChangeBuilder.Target) -> Void) {
        self.init(customCodes: code.customCodes, oneTimeCodes: code.oneTimeCodes, isActive: code.isActive, onSave: onSave, onDeactivate: onDeactivate)
    }

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
        customCodes.map { custom in
            Line(
                title: custom.code, detail: custom.summary, isActive: custom.isActive,
                identifier: "pricing.offerCodes.custom.\(custom.id)", target: .customCode(custom)
            )
        } + oneTimeCodes.map { batch in
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
                if isActive, self.isActive {
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
