//
//  DebugAppInformationContent+Compliance.swift
//  Atlas
//

#if DEBUG
import Foundation

extension DebugAppInformationContent {
    /// The trader details the App Compliance scenes show, as if typed
    /// before deciding.
    static let traderDetails = TraderDetails(
        name: "Northpier Studio Ltd",
        address: "14 Harbour Road, Dublin 2, D02 X285, Ireland",
        phone: "+353 1 555 0142",
        email: "support@northpier.dev"
    )

    /// A number that reads like an ICP Filing Number.
    static let icpNumber = "沪ICP备2026012345号-2A"

    /// Lumen's Reflect feature on another company's model, as filed with
    /// the Cyberspace Administration of China (sample values).
    static let aiFiling = AIFilingDetails(
        kind: .largeLanguageModel,
        number: "Shanghai-MingyuReflect-202603120001",
        name: "Mingyu Reflect Model",
        usesAnotherCompanysModel: true,
        technologyOwner: "Shanghai Mingyu Technology Co., Ltd."
    )

    /// What Claude Code suggests for Lumen's App Compliance: a trader with
    /// the imprint's details, stop selling in China mainland, no AI
    /// generation and nothing that needs a Security Assessment there, and
    /// not a regulated medical device.
    static var complianceSuggestions: [ComplianceSuggestion] {
        [
            ComplianceSuggestion(answer: .trader(traderDetails), evidence: AssistantEvidence(
                client: assistant,
                summary: "Trader, with these details",
                why: "Lumen sells a subscription in the EU, and the website’s imprint names the company and its address.",
                evidence: ["Lumen/Store/Products.storekit:4 — lumen.pro.yearly", "Website/imprint.html:12 — Northpier Studio Ltd, 14 Harbour Road"],
                couldNotSee: "Whether the phone number on the imprint still answers."
            )),
            ComplianceSuggestion(answer: .stopSellingInChina, evidence: AssistantEvidence(
                client: assistant,
                summary: "Stop selling in China mainland",
                why: "There’s no ICP filing anywhere in the project, and no Chinese localization.",
                evidence: ["Lumen/Resources — no zh-Hans.lproj", "Website/ — no ICP备 number in the footer"],
                couldNotSee: nil
            )),
            ComplianceSuggestion(answer: .securityAssessment(isNeeded: false), evidence: AssistantEvidence(
                client: assistant,
                summary: "Nothing that needs a Security Assessment",
                why: "Entries stay private to the person: nothing is shared with other people, and there’s no messaging.",
                evidence: ["Lumen/Sync/CloudSync.swift:22 — private CloudKit database only"],
                couldNotSee: nil
            )),
            ComplianceSuggestion(answer: .aiContent(AIContentAnswer(offersAI: false)), evidence: AssistantEvidence(
                client: assistant,
                summary: "No AI generation in China mainland",
                why: "Lumen uses no AI model: its prompts are a fixed list written by the team.",
                evidence: ["Lumen/Prompts/DailyPrompts.json — 365 written prompts", "Package.resolved — no AI or model SDKs"],
                couldNotSee: nil
            )),
            ComplianceSuggestion(answer: .medicalDevice(isRegulated: false), evidence: AssistantEvidence(
                client: assistant,
                summary: "Not a regulated medical device",
                why: "Lumen is a journal with mood check-ins. It doesn’t diagnose, treat or monitor a medical condition.",
                evidence: ["Lumen/Mood/MoodCheckIn.swift:18 — a 1–5 mood scale, stored on the device only"],
                couldNotSee: nil
            )),
        ]
    }

    /// Lumen Journal as App Store Connect's API shows it for App
    /// Compliance: sold everywhere, with no trader status in the EU and no
    /// ICP Filing Number in China mainland.
    static var compliance: ComplianceContent {
        ComplianceContent(territories: TerritoryCatalog.standard.territories.map { territory in
            ComplianceTerritory(id: availabilityID(territory.id), territoryID: territory.id, isAvailable: true, statuses: lumenStatuses(territory.id))
        })
    }

    private static func lumenStatuses(_ territoryID: String) -> Set<String> {
        if ComplianceRegion.europeanUnion.contains(territoryID) { return [ComplianceContent.traderNotProvided, "CANNOT_SELL"] }
        return territoryID == ComplianceRegion.chinaMainland ? [ComplianceContent.icpMissing] : ["AVAILABLE"]
    }

    /// Lumen taken off sale in China mainland: App Store Connect still asks
    /// both China mainland declarations, and No is the answer.
    static var complianceOutsideChina: ComplianceContent {
        ComplianceContent(territories: TerritoryCatalog.standard.territories.map { territory in
            let isChina = territory.id == ComplianceRegion.chinaMainland
            let statuses = isChina ? Set(["CANNOT_SELL"]) : lumenStatuses(territory.id)
            return ComplianceTerritory(id: availabilityID(territory.id), territoryID: territory.id, isAvailable: !isChina, statuses: statuses)
        })
    }

    /// Any other sample app: sold everywhere, nothing missing.
    static var settledCompliance: ComplianceContent {
        ComplianceContent(territories: TerritoryCatalog.standard.territories.map {
            ComplianceTerritory(id: availabilityID($0.id), territoryID: $0.id, isAvailable: true, statuses: ["AVAILABLE"])
        })
    }

    static func availabilityID(_ territoryID: String) -> String {
        "lumen-availability-\(territoryID)"
    }
}
#endif
