//
//  MCPPrompt+SuggestAllSteps.swift
//  Atlas
//

import Foundation

// `suggest_all`'s steps beyond the run's Store Page and App Information
// fields: App Compliance and Export Compliance, App Privacy and prices.
extension MCPPrompt {
    /// `suggest_all`'s App Compliance and Export Compliance: answers from
    /// the project that wait on their pages, planned and counted in the run
    /// (`MCPComplianceRunTarget`), so they're sent before `end_suggestions`.
    static let complianceStep = """
    App Compliance and Export Compliance are part of the run: before end_suggestions, plan them in \
    begin_suggestions as {area: info, page: appCompliance, field: <rule>} for each regulation get_compliance lists \
    as proposable and {area: info, page: exportCompliance, field: encryption}, and send them with the run. For App \
    Compliance, call get_compliance and send propose_compliance_answers with an answer, why and file:line evidence \
    for each regulation the project backs up (who sells it and where, from legal pages and the paywall; AI \
    generation, end-to-end encrypted messaging, medical claims), and could_not_see for the rest; never make up an \
    address, a phone number or a filing number. Only stopSelling becomes a change in Review & Push; the other \
    answers stay in Atlas for the person to enter in App Store Connect. For Export Compliance, call \
    get_export_compliance and read the project: the Info.plist's ITSAppUsesNonExemptEncryption, imports of \
    CryptoKit, CommonCrypto or Security, and Package.resolved, Podfile.lock or vendored code for OpenSSL, \
    BoringSSL, libsodium, WireGuard or a custom protocol. HTTPS and TLS through URLSession or Network, the Keychain, \
    CryptoKit and CommonCrypto are exempt; bundled or custom encryption isn't. Send propose_export_compliance with \
    usesEncryption, exempt and, when it isn't exempt, the three declaration answers and appDescription, with why \
    and file:line evidence; it queues the build's answer and, when needed, an encryption declaration in Review & \
    Push. If ITSAppUsesNonExemptEncryption is missing, say so: adding it stops the question for every build.
    """

    /// `suggest_all`'s App Privacy: the worksheet drafted from the project,
    /// as `fill_privacy_from_code` does. Apple has no API for App Privacy, so
    /// the worksheet stays on this Mac and the person enters the label in
    /// App Store Connect.
    static let privacyStep = """
    Then draft App Privacy. Call get_privacy_questionnaire for Apple's definitions, the data type and purpose ids \
    and the answers already in the worksheet, and answer the open questions it lists. Read PrivacyInfo.xcprivacy, \
    Package.resolved and the privacy manifests of third-party SDKs, and the code that sends data off the device \
    (analytics, crash reporting, sign-in, purchases, networking). Call propose_privacy_answers with collects, each \
    data type with its purposes, whether it's linked to the person and used for tracking, and file:line evidence; \
    leave alone what the person already reviewed. App Store Connect has no API for App Privacy: the worksheet \
    stays in Atlas, and the person enters the finished label in App Store Connect.
    """

    /// `suggest_all`'s prices: what App Store Connect charges beside what the
    /// project sells and shows, the differences proposed (outside the run's
    /// plan, which covers store and info fields only).
    static let pricingStep = """
    Then check prices against the project. Call get_app_price_and_availability (the app's own price and where \
    it's sold), get_subscriptions and get_prices (every subscription and in-app purchase price, with \
    get_price_points for a product's points in a territory). Read what the project sells and shows: StoreKit \
    product IDs and purchase calls in the code, a .storekit configuration's products, durations and prices, the \
    paywall's code and copy, and price constants. Propose only what differs or is missing, each with a \
    one-sentence reason and evidence (file:line): a price that differs with propose_prices (one of Apple's price \
    points), a subscription the code buys that App Store Connect lacks with propose_subscription, the app's own \
    price (0 for Free) with propose_app_price and where it's sold with propose_availability when they aren't set \
    up or differ from what the project says. A .storekit price is a local test value: propose it only when the \
    paywall or the project's docs show it too. Leave what already matches, never push, and say which products \
    you couldn't compare (an in-app purchase App Store Connect lacks can't be proposed yet).
    """
}
