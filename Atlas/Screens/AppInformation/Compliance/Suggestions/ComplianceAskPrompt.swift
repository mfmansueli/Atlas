//
//  ComplianceAskPrompt.swift
//  Atlas
//

import Foundation

/// What "Ask Claude Code…" on App Compliance starts Claude Code with, or
/// copies: answer what the page asks from the project, with
/// `get_compliance` and `propose_compliance_answers`.
enum ComplianceAskPrompt {
    /// The run's purpose, so the button finds its own run.
    static var purpose: ClaudeCodeRunPurpose { .ask(area: String(localized: "App Compliance")) }

    /// "Suggest App Compliance answers for Lumen in Atlas: …".
    static func text(app: String) -> String {
        String(localized: """
        Suggest App Compliance answers for \(app) in Atlas. Call get_compliance for what each regulation asks, \
        the answers it takes and the trader details Atlas prepared. Read the project: whether the app makes money \
        (paid app, subscriptions, in-app purchases, ads) for the Digital Services Act, and the company name, \
        address, phone and email from its legal pages, imprint, terms or support docs; an ICP Filing Number in \
        the app or its website files; for China mainland, whether it generates content with AI (chatbots, image or \
        video generation, voice or face changes: AI SDKs, model APIs, on-device models), whose model it is and any \
        CAC filing number and name in the project, and whether it has features that need a Security Assessment \
        (sharing AI-generated content with other people, end-to-end encrypted messaging); and whether the app \
        diagnoses, treats or monitors a medical condition, for the medical device question. Send them with \
        propose_compliance_answers, each with why and evidence (file and line), and say in could_not_see what the \
        project can't show. Never make up an address, a phone number, an ICP Filing Number or a filing number: \
        leave out what you can't find. The person accepts each answer in Atlas and enters it in App Store Connect.
        """)
    }
}
