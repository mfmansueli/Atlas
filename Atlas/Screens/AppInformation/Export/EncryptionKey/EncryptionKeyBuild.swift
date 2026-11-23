//
//  EncryptionKeyBuild.swift
//  Atlas
//

import Foundation

/// One of the app's newest uploaded builds, as far as the export
/// compliance key goes: whether App Store Connect has its encryption
/// answer (`usesNonExemptEncryption`, null until someone answers or the
/// build's Info.plist does).
struct EncryptionKeyBuild: Identifiable, Hashable, Sendable {
    var id: String
    /// The build number, e.g. "43".
    var number: String?
    var uploadedDate: Date?
    var usesNonExemptEncryption: Bool?
    /// `PROCESSING`, `FAILED`, `INVALID` or `VALID`.
    var processingState: String?

    /// Processed: only then does a missing answer mean anything.
    var isProcessed: Bool { processingState == nil || processingState == "VALID" }

    init(id: String, number: String?, uploadedDate: Date? = nil, usesNonExemptEncryption: Bool?, processingState: String? = "VALID") {
        self.id = id
        self.number = number
        self.uploadedDate = uploadedDate
        self.usesNonExemptEncryption = usesNonExemptEncryption
        self.processingState = processingState
    }

    init(_ resource: AppStoreConnectResource<BuildAttributes>) {
        self.init(
            id: resource.id,
            number: resource.attributes.version,
            uploadedDate: resource.attributes.uploadedDate.flatMap { try? Date($0, strategy: .iso8601) },
            usesNonExemptEncryption: resource.attributes.usesNonExemptEncryption,
            processingState: resource.attributes.processingState
        )
    }
}
