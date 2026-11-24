//
//  MedicalDeviceCheck.swift
//  Atlas
//

import Foundation

/// Whether Apple asks the app to declare its regulated medical device
/// status: apps sold in the EEA, the UK or the US whose primary or
/// secondary category is Medical or Health & Fitness, or whose age rating
/// says Medical or Treatment Information is frequent. Apple's API doesn't
/// show the declaration itself.
enum MedicalDeviceCheck: Hashable, Sendable {
    /// Neither the categories nor the age rating ask for it.
    case notNeeded
    /// It would be asked, but the app isn't sold where it applies.
    case notSoldThere
    /// Asked because of this category, e.g. `HEALTH_AND_FITNESS`.
    case category(String)
    /// Asked because the age rating says Medical or Treatment Information
    /// is frequent.
    case frequentMedicalInformation

    static let categories: Set<String> = ["MEDICAL", "HEALTH_AND_FITNESS"]

    init(_ content: ComplianceContent, general: GeneralValues, ageRating: AgeRatingAnswers) {
        let category = [general.primaryCategory, general.secondaryCategory].compactMap(\.self).first(where: Self.categories.contains)
        let isFrequent = ageRating[.medical] == .frequent
        guard category != nil || isFrequent else {
            self = .notNeeded
            return
        }
        if content.territories != nil, !content.isSold(in: ComplianceRegion.medicalDevice) {
            self = .notSoldThere
        } else if let category {
            self = .category(category)
        } else {
            self = .frequentMedicalInformation
        }
    }

    /// Apple asks for the declaration.
    var isAsked: Bool {
        switch self {
        case .notNeeded, .notSoldThere: false
        case .category, .frequentMedicalInformation: true
        }
    }
}
