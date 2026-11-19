//
//  AIContentAnswer.swift
//  Atlas
//

import Foundation

/// The person's answer to China mainland's AI-generated or synthetic
/// content declaration: whether the app offers it there (chatbots, image or
/// video generation, voice or face changes), and with which filing.
struct AIContentAnswer: Hashable, Codable, Sendable {
    /// Yes: it offers AI generation in China mainland. No also covers
    /// features that are off or geoblocked there.
    var offersAI: Bool
    var filing: AIFilingDetails

    init(offersAI: Bool, filing: AIFilingDetails = AIFilingDetails()) {
        self.offersAI = offersAI
        self.filing = filing
    }

    /// Ready to enter in App Store Connect: a No, or a Yes with its filing.
    var isComplete: Bool { !offersAI || filing.isComplete }
}
