//
//  ReviewRiskEULAReader.swift
//  Atlas
//

import Foundation

/// Reads whether the app has its own license agreement in App Store
/// Connect (`GET /v1/apps/{id}/endUserLicenseAgreement`, Apple's
/// OpenAPI spec: an `endUserLicenseAgreements` resource with
/// `agreementText` and its territories). No agreement (`data: null` or a
/// 404) means Apple's standard EULA applies, and then the store texts
/// need a link to it for subscriptions (3.1.2(c)).
struct ReviewRiskEULAReader {
    let transport: any PushTransport

    static func path(appID: String) -> String {
        "/v1/apps/\(appID)/endUserLicenseAgreement?fields%5BendUserLicenseAgreements%5D=agreementText"
    }

    /// True with a custom agreement, false without; nil when it couldn't
    /// be read.
    func hasCustomEULA(appID: String) async -> Bool? {
        do {
            let response = try await transport.fetch(Self.path(appID: appID))
            return Self.hasAgreement(in: response.data)
        } catch AppStoreConnectError.notFound {
            return false
        } catch {
            return nil
        }
    }

    /// Whether the response carries an agreement with text; nil for a body
    /// that isn't App Store Connect's.
    static func hasAgreement(in data: Data) -> Bool? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let resource = object["data"] as? [String: Any] else { return object.keys.contains("data") ? false : nil }
        let text = (resource["attributes"] as? [String: Any])?["agreementText"] as? String
        // An agreement without text is still Apple's record of one.
        return text.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? true
    }
}
