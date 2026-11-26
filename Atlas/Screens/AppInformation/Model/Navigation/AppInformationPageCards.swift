//
//  AppInformationPageCards.swift
//  Atlas
//

import Foundation

/// App Information's seven pages as cards for the strip (board 88): in
/// the page order, with "Only Apple sees" before the first page that never
/// shows on the App Store (App Review, then Export Compliance).
enum AppInformationPageCards {
    static let order: [AppInformationPage] = [
        .general, .appCompliance, .ageRating, .accessibility, .appPrivacy, .appReview, .exportCompliance,
    ]

    static var onlyAppleSeesTitle: String {
        String(localized: "Only Apple sees", comment: "kind:label · separator in App Information's page strip before App Review and Export Compliance")
    }

    static func items(status: (AppInformationPage) -> AppInformationPageStatus) -> [PageCardItem<AppInformationPage>] {
        order.enumerated().map { index, page in
            let pageStatus = status(page)
            let startsAppleGroup = page.isSeenOnlyByApple && (index == 0 || !order[index - 1].isSeenOnlyByApple)
            return PageCardItem(
                id: page,
                title: page.title,
                systemImage: page.systemImage,
                status: pageStatus.text,
                tone: pageStatus.tone,
                groupTitle: startsAppleGroup ? onlyAppleSeesTitle : nil,
                isLoading: pageStatus.isLoading,
                identifier: page.rawValue
            )
        }
    }
}
