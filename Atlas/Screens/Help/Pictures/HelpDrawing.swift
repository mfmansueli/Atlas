//
//  HelpDrawing.swift
//  Atlas
//

import Foundation

/// A Help picture Atlas draws itself instead of bundling a screenshot:
/// App Store Connect's pages in "Get your App Store Connect key"
/// (README-Welcome), with an orange ring around what to click. The raw
/// value is the name the article writes, as in `![caption](help-connect-1)`.
enum HelpDrawing: String, CaseIterable, Sendable {
    /// Users and Access, then Integrations.
    case connectIntegrations = "help-connect-1"
    /// Team Keys, + and Admin in Generate API Key.
    case connectTeamKey = "help-connect-2"
    /// Download in the key's row.
    case connectDownload = "help-connect-3"
    /// The Issuer ID at the top of the page and the Key ID in the key's row.
    case connectIDs = "help-connect-4"

    /// The key the pictures show. Both IDs are made up, as in the design.
    static let sampleKeyID = "2X9R4HXF34"
    static let sampleIssuerID = "69a6de70-3c1f-47e3-e053-5b8c7c11a4d1"

    /// What VoiceOver reads for the whole picture: what to click, not
    /// every word drawn in it.
    var accessibilityLabel: String {
        switch self {
        case .connectIntegrations:
            String(localized: "Picture: in App Store Connect, Users and Access, then Integrations", comment: "kind:accessibility-label")
        case .connectTeamKey:
            String(localized: "Picture: in App Store Connect, Team Keys, the Add button, then Admin access", comment: "kind:accessibility-label")
        case .connectDownload:
            String(localized: "Picture: in App Store Connect, Download in your key’s row", comment: "kind:accessibility-label")
        case .connectIDs:
            String(
                localized: "Picture: in App Store Connect, the Issuer ID at the top and the Key ID in your key’s row",
                comment: "kind:accessibility-label"
            )
        }
    }
}
