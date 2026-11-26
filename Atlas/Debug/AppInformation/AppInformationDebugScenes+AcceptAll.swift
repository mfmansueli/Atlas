//
//  AppInformationDebugScenes+AcceptAll.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// `info-accept-all` (board 88): Lumen with every page done but for its
/// suggestions, so Accept All Pages leaves all seven cards Ready. The
/// built-in suggestions (copyright, the 1.3 contact phone) and Claude
/// Code's (categories, release, notes, six age answers, accessibility
/// features) wait; the seventh age question is answered, App Compliance's
/// regulations are settled and declared, App Privacy is published and
/// Export Compliance is answered.
extension AppInformationDebugScenes {
    static let acceptAllIDs = ["info-accept-all"]

    @MainActor
    static func acceptAllScene() -> AnyView {
        var appInformation = DebugAppInformationServices(privacy: DebugPrivacyWorksheets.published)
        appInformation.hasOutdatedDetails = true
        appInformation.lumenCompliance = DebugAppInformationContent.settledCompliance
        appInformation.opening = DebugAppInformationServices.Opening { model in
            model.page = .general
            // Claude Code suggests the other six.
            model.setAnswer(.negative, for: .advertising)
            let declared: [ComplianceRule] = [.securityAssessment, .aiGeneratedContent, .medicalDevice, .vietnamGameLicense]
            declared.forEach { model.setDeclared(true, for: $0) }
        }
        var services = WorkspaceServices.debug
        services.appInformation = appInformation
        let scene = DebugMainScene(
            services: services,
            section: .appInformation,
            pendingChanges: [],
            suggestions: SuggestionsDebugData.store(includesCodeAnswers: true)
        )
        return SuggestionsDebugScenes.with(.connected, scene)
    }
}
#endif
