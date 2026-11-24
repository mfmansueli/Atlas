//
//  AgeRatingPreviewCard.swift
//  Atlas
//

import SwiftUI

/// The rating preview: the rating the App Store would show, what the
/// answers calculate, what App Store Connect has now, and the regional
/// ratings.
struct AgeRatingPreviewCard: View {
    let preview: AgeRatingPreview
    let currentRating: String?
    let changesWithPush: Bool

    var body: some View {
        Card {
            Text("Rating preview")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
            HStack(alignment: .top, spacing: Spacing.medium) {
                Text(preview.effective.title)
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 64, height: 64)
                    .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.label, lineWidth: 2))
                    .accessibilityLabel(Text("Rating \(preview.effective.title)"))
                    .accessibilityIdentifier("appInformation.age.rating")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calculated: **\(preview.calculated.title)**")
                    Text("In App Store Connect now: \(currentRating ?? String(localized: "not rated"))")
                        .foregroundStyle(Palette.label2)
                }
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            }
            if changesWithPush {
                Pill(text: String(localized: "Changes on push"), systemImage: "circle.fill", style: .accent)
            }
            Text("By region")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .padding(.top, Spacing.xxSmall)
            VStack(spacing: 0) {
                regionRow(String(localized: "Australia"), preview.australia)
                regionRow(String(localized: "Brazil · self-rated"), preview.brazil)
                regionRow(String(localized: "Republic of Korea"), preview.korea)
                regionRow(String(localized: "Everywhere else"), preview.effective.title)
            }
            Text("Regional values follow Apple’s published tables. Regulators in Australia and Brazil can replace them with an official rating.")
                .font(.footnote)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("appInformation.age.preview")
    }

    private func regionRow(_ region: String, _ rating: String) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(region)
                Spacer()
                Text(rating)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.vertical, Spacing.xxSmall + 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AgeRatingPreviewCard(
        preview: AgeRatingCalculator.preview(for: AgeRatingAnswers([.wellness: .affirmative])),
        currentRating: "4+",
        changesWithPush: true
    )
    .frame(width: 250)
    .padding()
}
