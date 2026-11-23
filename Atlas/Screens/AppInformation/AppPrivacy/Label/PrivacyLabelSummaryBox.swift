//
//  PrivacyLabelSummaryBox.swift
//  Atlas
//

import SwiftUI

/// The end of the worksheet: the App Privacy label the reviewed answers
/// make, as the product page groups it (used to track, linked, not
/// linked), updating as the person answers.
struct PrivacyLabelSummaryBox: View {
    let preview: PrivacyLabelPreview

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("The label people will see", comment: "kind:section-title")
                .font(.callout.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if !preview.isAnswered {
                Text("Answer the first question to see the label.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if preview.isDataNotCollected {
                Text("Data Not Collected")
                    .font(.callout)
                    .accessibilityIdentifier("appInformation.appPrivacy.labelPreview.notCollected")
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xxSmall) {
                    ForEach(PrivacyLabelPreview.Kind.allCases) { kind in
                        GridRow {
                            Text(title(of: kind))
                                .foregroundStyle(Palette.label2)
                                .gridColumnAlignment(.leading)
                            Text(preview.categoryNames(in: kind))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("appInformation.appPrivacy.labelPreview.\(kind.rawValue)")
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .font(.callout)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.labelPreview")
    }

    private func title(of kind: PrivacyLabelPreview.Kind) -> String {
        switch kind {
        case .tracking: String(localized: "Used to track you", comment: "kind:field-label")
        case .linked: String(localized: "Linked to you", comment: "kind:field-label")
        case .notLinked: String(localized: "Not linked to you", comment: "kind:field-label")
        }
    }
}

#Preview {
    PrivacyLabelSummaryBox(preview: PrivacyLabelPreview(answers: PrivacyReviewedAnswers(collects: true, collected: [
        .userId: PrivacyAnswer(collected: true, purposes: [.appFunctionality], linked: true),
        .crash: PrivacyAnswer(collected: true, purposes: [.appFunctionality]),
    ])))
    .padding()
    .frame(width: 520)
}
