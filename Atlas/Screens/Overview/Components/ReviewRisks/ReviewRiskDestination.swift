//
//  ReviewRiskDestination.swift
//  Atlas
//

import Foundation

/// Where Show takes the person for a risk: its section, and the page or
/// intent inside it when there is one (App Compliance, Age Rating, App
/// Review).
enum ReviewRiskDestination {
    static func intent(for check: ReviewRiskCheckID) -> WorkspaceIntent? {
        switch check {
        case .chinaSecurityAssessment, .chinaAIContent: .openAppInformationPage(.appCompliance)
        case .ageRating: .openAppInformationPage(.ageRating)
        case .userContent, .accountDeletion, .signInWithApple, .purposeStrings: .openAppInformationPage(.appReview)
        case .links: .openAppInformationPage(.appPrivacy)
        default: nil
        }
    }
}
