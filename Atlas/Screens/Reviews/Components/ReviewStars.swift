//
//  ReviewStars.swift
//  Atlas
//

import SwiftUI

/// "★★★☆☆", amber, or red for 1 and 2 stars.
struct ReviewStars: View {
    let rating: Int

    var body: some View {
        Text(ReviewText.stars(rating))
            .font(.subheadline)
            .tracking(1)
            .foregroundStyle(rating <= 2 ? Palette.err : Palette.sectionReviews)
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
