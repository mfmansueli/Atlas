//
//  MCPReleaseSubmitProposal.swift
//  Atlas
//

import Foundation

/// `propose_release_action`'s submit arguments checked like the Submit
/// sheet checks them: a build App Review can take, What's New in every
/// language (a suggestion waiting counts, the person accepts it in the
/// sheet), an encryption answer, a release date still ahead, App Review's
/// information, and events that can go with the version. What would keep
/// Submit off is collected in `refusals`, each with how to fix it.
@MainActor
struct MCPReleaseSubmitProposal {
    var submission: ReleaseProposalSubmission?
    var refusals: [String] = []
    /// What the person will see or do in the sheet.
    var notes: [String] = []

    static func make(
        from arguments: MCPToolArguments, status: ReleaseStatus, readiness: MCPReleaseReadiness, now: Date
    ) throws -> MCPReleaseSubmitProposal {
        var proposal = MCPReleaseSubmitProposal()
        let version = status.version.versionString
        let build = try proposal.build(from: arguments, in: status)
        let timing = try proposal.timing(from: arguments, version: status.version, now: now)
        let encryption = try proposal.encryption(from: arguments, build: build, readiness: readiness)
        let eventIDs = try proposal.events(from: arguments, readiness: readiness)
        let productIDs = try proposal.products(from: arguments, status: status)
        proposal.checkWhatsNew(readiness)
        if !status.isReviewInformationComplete {
            proposal.refusals.append(String(localized: """
            App Review’s information for \(version) is incomplete (a contact, and the demo account when sign-in is needed): \
            propose it with suggest_fields (get_app_information shows the App Review fields), then propose submit again.
            """))
        }
        if readiness.pendingChanges > 0 {
            proposal.notes.append(String(localized: "\(readiness.pendingChanges) changes wait in Review & Push: the sheet pushes them with the submission unless the person unticks it."))
        }
        guard proposal.refusals.isEmpty, let build else { return proposal }
        proposal.submission = try ReleaseProposalSubmission(
            buildID: build.id, buildNumber: build.number, releaseType: timing.releaseType, releaseDate: timing.date,
            isPhased: arguments.optionalBool("phasedRelease") ?? true, encryption: encryption?.rawValue, eventIDs: eventIDs,
            pushesChanges: arguments.optionalBool("pushesChanges"), productIDs: productIDs
        )
        return proposal
    }

    // MARK: - Build

    /// `buildId` or `buildNumber`, else the sheet's: the attached build,
    /// else the newest that's ready.
    private mutating func build(from arguments: MCPToolArguments, in status: ReleaseStatus) throws -> ReleaseBuild? {
        let version = status.version.versionString
        let ready = status.builds.filter(\.isSelectable)
        let readyNames = ready.map(\.number).formatted(.list(type: .or))
        let id = try arguments.optionalString("buildId")
        let number = try arguments.optionalString("buildNumber")
        guard id != nil || number != nil else {
            guard let defaultID = ReleaseViewModel.defaultBuildID(in: status), let build = status.builds.first(where: { $0.id == defaultID }) else {
                let processing = status.builds.contains { $0.processing == .processing }
                refusals.append(processing
                    ? String(localized: "No build of \(version) is ready: Apple is still processing the one uploaded. Propose submit once get_release shows it VALID.")
                    : String(localized: "No build of \(version) is uploaded. The person uploads one from Xcode; propose submit once get_release lists it VALID."))
                return nil
            }
            return build
        }
        guard let build = status.builds.first(where: { $0.id == id || $0.number == number }) else {
            refusals.append(ready.isEmpty
                ? String(localized: "\(version) has no such build, and none is ready.")
                : String(localized: "\(version) has no such build. Ready: \(readyNames) (get_release’s builds)."))
            return nil
        }
        guard build.isSelectable else {
            let why = build.isExpired
                ? String(localized: "it expired")
                : build.processing == .processing ? String(localized: "Apple is still processing it") : String(localized: "Apple couldn’t process it")
            let other = ready.isEmpty ? "" : String(localized: " Ready: \(readyNames).")
            refusals.append(String(localized: "Build \(build.number) can’t go to App Review: \(why).\(other)"))
            return nil
        }
        return build
    }

    // MARK: - Release

    /// `releaseType` (and `releaseDate`), else what the version has.
    private mutating func timing(from arguments: MCPToolArguments, version: ReleaseVersion, now: Date) throws -> ReleaseTiming {
        let dateText = try arguments.optionalString("releaseDate")
        let date: Date?
        if let dateText {
            guard let parsed = AppStoreConnectDate.date(dateText) ?? ISO8601DateFormatter().date(from: dateText) else {
                throw MCPToolError.invalidArgument(name: "releaseDate", expected: String(localized: "an ISO 8601 date and time, e.g. 2026-12-01T09:00:00Z"))
            }
            date = SubmissionOptions.onTheHour(parsed)
        } else {
            date = nil
        }
        let timing: ReleaseTiming
        if let type = try arguments.optionalString("releaseType") {
            switch type.uppercased().replacingOccurrences(of: " ", with: "_") {
            case "MANUAL": timing = .manual
            case "AFTER_APPROVAL", "AFTERAPPROVAL": timing = .afterApproval
            case "SCHEDULED":
                guard let date = date ?? version.timing.date else {
                    refusals.append(String(localized: "A SCHEDULED release needs releaseDate (ISO 8601, on the hour)."))
                    return .manual
                }
                timing = .scheduled(date)
            default:
                throw MCPToolError.invalidArgument(name: "releaseType", expected: String(localized: "MANUAL, AFTER_APPROVAL or SCHEDULED"))
            }
        } else if let date {
            timing = .scheduled(date)
        } else {
            timing = version.timing
        }
        if let date = timing.date, date <= now {
            refusals.append(String(localized: "The release date \(date.formatted(.iso8601)) has passed: pick one still ahead, or another releaseType."))
        }
        return timing
    }

    // MARK: - Encryption

    /// `encryption`, else the one the build or Export Compliance has;
    /// refused when there's none.
    private mutating func encryption(from arguments: MCPToolArguments, build: ReleaseBuild?, readiness: MCPReleaseReadiness) throws -> EncryptionAnswer? {
        let known = readiness.encryption(for: build)
        guard let text = try arguments.optionalString("encryption") else {
            if known == nil, build != nil {
                refusals.append(String(localized: """
                Nobody answered the encryption question for this build: read get_export_compliance, check the code's use of \
                encryption, and pass encryption (exempt, noEncryption or other).
                """))
            }
            return nil
        }
        let key = text.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
        let answer: EncryptionAnswer? = switch key {
        case "exempt", "standard", "standardencryption": .exempt
        case "noencryption", "none", "no": .noEncryption
        case "other", "nonexempt": .other
        default: nil
        }
        guard let answer else {
            throw MCPToolError.invalidArgument(name: "encryption", expected: String(localized: "exempt, noEncryption or other"))
        }
        if let known, known.usesNonExemptEncryption != answer.usesNonExemptEncryption {
            notes.append(String(localized: "The build answers “\(known.title)”; Submit writes “\(answer.title)” on it instead."))
        }
        return answer
    }

    // MARK: - Events

    /// `eventIds`: each must be able to go with the version. Nil leaves
    /// the sheet's ticks.
    private mutating func events(from arguments: MCPToolArguments, readiness: MCPReleaseReadiness) throws -> [InAppEvent.ID]? {
        guard let ids = try arguments.optionalStrings("eventIds") else { return nil }
        let offered = readiness.offeredEvents
        var kept: [InAppEvent.ID] = []
        for id in ids where !kept.contains(id) {
            guard offered.contains(where: { $0.id == id }) else {
                let names = offered.map { "\(ReleaseViewModel.displayName(of: $0)) (\($0.id))" }
                refusals.append(names.isEmpty
                    ? String(localized: "In-App Event \(id) can’t go with the version: no draft event can now (get_in_app_events).")
                    : String(localized: "In-App Event \(id) can’t go with the version (only drafts that haven’t ended can). These can: \(names.formatted(.list(type: .or)))."))
                continue
            }
            kept.append(id)
        }
        if !kept.isEmpty {
            notes.append(String(localized: """
            The sheet checks each event's deep link, dates and art before Submit; get_in_app_events' missingForReview says \
            what's left.
            """))
        }
        return kept
    }

    // MARK: - Products

    /// `productIds`: each must be Ready to Submit (get_release's
    /// productsToSubmit). Nil leaves the sheet's ticks: all of them.
    private mutating func products(from arguments: MCPToolArguments, status: ReleaseStatus) throws -> [SubmissionProduct.ID]? {
        guard let ids = try arguments.optionalStrings("productIds") else { return nil }
        let offered = status.productsToSubmit
        var kept: [SubmissionProduct.ID] = []
        for id in ids {
            guard let product = offered.first(where: { $0.id == id || $0.productID == id }) else {
                let names = offered.map { "\($0.name) (\($0.productID))" }
                refusals.append(names.isEmpty
                    ? String(localized: "\(id) can’t go with the version: no subscription or in-app purchase is Ready to Submit (get_subscriptions).")
                    : String(localized: "\(id) isn’t Ready to Submit. These are: \(names.formatted(.list(type: .or)))."))
                continue
            }
            if !kept.contains(product.id) { kept.append(product.id) }
        }
        let left = offered.filter { $0.isFirst && !kept.contains($0.id) }
        if !left.isEmpty {
            let names = left.map { "\($0.name) (\($0.productID))" }.formatted(.list(type: .and))
            notes.append(String(localized: "\(names) only reach App Review with a version: left out, they wait for the next one."))
        }
        return kept
    }

    // MARK: - What's New

    private mutating func checkWhatsNew(_ readiness: MCPReleaseReadiness) {
        let missing = readiness.missingWhatsNew
        if !missing.isEmpty {
            let names = missing.map { "\($0.locale.name) (\($0.locale.code))" }.formatted(.list(type: .and))
            refusals.append(String(localized: """
            What’s New is missing in \(names): write it with suggest_fields (field whatsNew, each locale), then propose submit again.
            """))
        }
        let suggested = readiness.suggestedWhatsNew
        if !suggested.isEmpty {
            let codes = suggested.map(\.locale.code).formatted(.list(type: .and))
            notes.append(String(localized: "What’s New in \(codes) waits as a suggestion: the person accepts it in the Submit sheet."))
        }
    }
}
