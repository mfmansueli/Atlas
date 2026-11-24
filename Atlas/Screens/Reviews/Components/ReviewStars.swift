//
//  ReviewStars.swift
//  Atlas
//

import SwiftUI

/// Five stars, filled up to the rating (README-DS §13: SF Symbols, not
/// "★☆" characters), amber, or red for 1 and 2 stars unless `tint` says.
struct ReviewStars: View {
    let rating: Int
    /// Overrides the colour by rating (the average on Ratings stays amber).
    var tint: Color?

    var body: some View {
        let filled = max(0, min(rating, 5))
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < filled ? "star.fill" : "star")
            }
        }
        .font(.subheadline)
        .imageScale(.small)
        .foregroundStyle(tint ?? (rating <= 2 ? Palette.err : Palette.sectionReviews))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ReviewText.starsSpoken(rating)))
    }
}

#Preview {
    VStack(alignment: .leading) {
        ReviewStars(rating: 5)
        ReviewStars(rating: 2)
    }
    .padding()
}
