//
//  EncryptionKeyDetection.swift
//  Atlas
//

import Foundation

/// Whether the app's builds already answer the export compliance question
/// themselves, as far as Atlas can tell without starting an assistant:
/// from an assistant's report, from the project folder Atlas read, or
/// inferred from the newest uploads (they arrived with the answer set,
/// and Atlas didn't answer them). Each says how it knows.
enum EncryptionKeyDetection: Hashable, Sendable {
    /// An assistant added it, or found it there (`report_encryption_key`).
    case reported(EncryptionKeyReport)
    /// Atlas read it in the app target's build settings or Info.plist.
    case inProject(EncryptionKeyProjectState.Key)
    /// Atlas read the app targets and didn't find it.
    case notInProject(targets: [String])
    /// The newest builds arrived with the answer already set, newest first.
    case inferred(value: EncryptionKeyValue, builds: [String])
    /// The newest processed build is still waiting for its answer: the
    /// key isn't in it.
    case missing(build: String?)
    case unknown

    /// The newest processed builds that arrived answered, in a row, are
    /// enough to infer it; a build Atlas answered itself (`answeredInAtlas`,
    /// build ids) isn't.
    static func detect(
        report: EncryptionKeyReport?,
        project: EncryptionKeyProjectState,
        builds: [EncryptionKeyBuild],
        answeredInAtlas: Set<String> = []
    ) -> EncryptionKeyDetection {
        if let report, report.isDone { return .reported(report) }
        switch project {
        case let .found(key): return .inProject(key)
        case let .notFound(targets): return .notInProject(targets: targets)
        case .unknown, .noFolder, .unreadable: break
        }
        let processed = builds.filter(\.isProcessed)
        guard let newest = processed.first else { return .unknown }
        guard let flag = newest.usesNonExemptEncryption else { return .missing(build: newest.number) }
        let answered = processed.prefix { $0.usesNonExemptEncryption == flag && !answeredInAtlas.contains($0.id) }
        guard !answered.isEmpty else { return .unknown }
        return .inferred(value: EncryptionKeyValue(usesNonExemptEncryption: flag), builds: answered.map { $0.number ?? $0.id })
    }

    /// What the key says, when Atlas knows or infers it.
    var value: EncryptionKeyValue? {
        switch self {
        case let .reported(report): report.value
        case let .inProject(key): key.value
        case let .inferred(value, _): value
        case .notInProject, .missing, .unknown: nil
        }
    }

    /// The builds answer it themselves.
    var isDone: Bool { value != nil }

    /// For `get_export_compliance`: reported, readInProject, inferred or
    /// unknown.
    var state: String {
        switch self {
        case .reported: "reported"
        case .inProject, .notInProject: "readInProject"
        case .inferred, .missing: "inferred"
        case .unknown: "unknown"
        }
    }

    /// Whether the key is in the app; nil when Atlas can't tell.
    var present: Bool? {
        switch self {
        case .reported, .inProject, .inferred: true
        case .notInProject, .missing: false
        case .unknown: nil
        }
    }

    /// The card's line once it's done.
    var headline: String? {
        switch self {
        case let .reported(report): report.headline
        case let .inProject(key): String(localized: "In \(key.whereText) — builds uploaded from now on answer it")
        case .inferred: String(localized: "Builds already answer it")
        case .notInProject, .missing, .unknown: nil
        }
    }

    /// How Atlas knows: what's read, reported or only inferred.
    var detail: String? {
        switch self {
        case let .reported(report):
            return report.places.isEmpty ? nil : report.places.map(\.text).joined(separator: "\n")
        case let .inProject(key):
            let code = key.code.map { String(localized: ", code \($0)") } ?? ""
            return String(localized: "\(EncryptionKeyAnswer.key) = \(key.value.rawValue)\(code). Atlas read it in the project folder.")
        case let .inferred(value, builds):
            let list = builds.formatted(.list(type: .and))
            let they = builds.count == 1 ? String(localized: "Build \(list) arrived") : String(localized: "Builds \(list) arrived")
            return String(localized: """
            \(they) with the encryption answer already set (\(value.meaning)), which is what the key does. An answer given \
            in App Store Connect for each build looks the same, and Atlas hasn’t checked the project: this is inferred.
            """)
        case let .notInProject(targets):
            let names = targets.formatted(.list(type: .and))
            return String(localized: """
            Atlas didn’t find the key in \(names)’s Release build settings or Info.plist. Settings in .xcconfig files aren’t read.
            """)
        case let .missing(build?):
            return String(localized: "Build \(build) is still waiting for its encryption answer, so the key isn’t in it.")
        case .missing(nil):
            return String(localized: "The newest build is still waiting for its encryption answer, so the key isn’t in it.")
        case .unknown:
            return nil
        }
    }

    /// The build ids Atlas itself answered, from the pushes it made (a
    /// `PATCH /v1/builds/{id}`).
    static func answeredInAtlas(_ records: [PushRecord]) -> Set<String> {
        let prefix = "/v1/builds/"
        return Set(records.flatMap(\.pushed).flatMap(\.requests).compactMap { request in
            guard request.path.hasPrefix(prefix) else { return nil }
            let id = request.path.dropFirst(prefix.count).split(separator: "/").first.map(String.init)
            return id?.isEmpty == false ? id : nil
        })
    }
}
