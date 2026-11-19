//
//  ComplianceAnswers.swift
//  Atlas
//

import Foundation

/// The person's App Compliance answers, kept on this Mac for one app.
/// Apple's API takes none of them, so they wait here until the person has
/// entered them in App Store Connect.
struct ComplianceAnswers: Hashable, Codable, Sendable {
    var trader: TraderDecision?
    /// The trader details as edited; nil while they're the prepared ones.
    var traderDetails: TraderDetails?
    /// "Add an ICP Filing Number" is chosen.
    var addsICPNumber = false
    var icpNumber = ""
    /// What the person says is declared in App Store Connect, for the
    /// rules Apple's API can't show: the Vietnam license, the medical
    /// device declaration and China mainland's AI content and Security
    /// Assessment.
    var declared: Set<ComplianceRule> = []
    /// Whether the app is a regulated medical device, as accepted from an
    /// assistant; nil until answered. It's declared in App Store Connect.
    var regulatedMedicalDevice: Bool?
    /// China mainland: AI-generated or synthetic content; nil until
    /// answered.
    var aiContent: AIContentAnswer?
    /// China mainland: whether the app needs a Security Assessment; nil
    /// until answered.
    var needsSecurityAssessment: Bool?

    init(
        trader: TraderDecision? = nil,
        traderDetails: TraderDetails? = nil,
        addsICPNumber: Bool = false,
        icpNumber: String = "",
        declared: Set<ComplianceRule> = [],
        regulatedMedicalDevice: Bool? = nil,
        aiContent: AIContentAnswer? = nil,
        needsSecurityAssessment: Bool? = nil
    ) {
        self.trader = trader
        self.traderDetails = traderDetails
        self.addsICPNumber = addsICPNumber
        self.icpNumber = icpNumber
        self.declared = declared
        self.regulatedMedicalDevice = regulatedMedicalDevice
        self.aiContent = aiContent
        self.needsSecurityAssessment = needsSecurityAssessment
    }

    /// Every field is optional when decoding, so answers saved before a
    /// field existed still load.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trader = try container.decodeIfPresent(TraderDecision.self, forKey: .trader)
        traderDetails = try container.decodeIfPresent(TraderDetails.self, forKey: .traderDetails)
        addsICPNumber = try container.decodeIfPresent(Bool.self, forKey: .addsICPNumber) ?? false
        icpNumber = try container.decodeIfPresent(String.self, forKey: .icpNumber) ?? ""
        declared = try container.decodeIfPresent(Set<ComplianceRule>.self, forKey: .declared) ?? []
        regulatedMedicalDevice = try container.decodeIfPresent(Bool.self, forKey: .regulatedMedicalDevice)
        aiContent = try container.decodeIfPresent(AIContentAnswer.self, forKey: .aiContent)
        needsSecurityAssessment = try container.decodeIfPresent(Bool.self, forKey: .needsSecurityAssessment)
    }

    /// A number is chosen and reads like one.
    var hasValidICPNumber: Bool { addsICPNumber && ICPFilingNumber.isValid(icpNumber) }

    /// A number is typed and doesn't read like one.
    var hasMalformedICPNumber: Bool {
        addsICPNumber && !ICPFilingNumber.normalized(icpNumber).isEmpty && !ICPFilingNumber.isValid(icpNumber)
    }
}
