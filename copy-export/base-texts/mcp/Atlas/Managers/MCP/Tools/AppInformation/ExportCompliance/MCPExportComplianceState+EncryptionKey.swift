//
//  MCPExportComplianceState+EncryptionKey.swift
//  Atlas
//

import Foundation

// get_export_compliance's `infoPlistKey`: whether the app's builds answer
// the question themselves (reported, read in the project, inferred from
// the newest uploads, or unknown), what the key must say once the answer
// is settled, and how to get it added.
extension MCPExportComplianceState {
    var keyReadiness: EncryptionKeyReadiness {
        EncryptionKeyReadiness.make(notes: notes, export: export)
    }

    func infoPlistKeyJSON(report: EncryptionKeyReport?, project: EncryptionKeyProjectState, builds: [EncryptionKeyBuild]) -> JSONValue {
        let readiness = keyReadiness
        let card = EncryptionKeyCardModel(
            readiness: readiness,
            detection: EncryptionKeyDetection.detect(report: report, project: project, builds: builds),
            report: report,
            shownValue: answers.usesNonExemptEncryption.map(EncryptionKeyValue.init(usesNonExemptEncryption:))
        )
        let detection = card.detection
        var key: [String: JSONValue] = [
            "state": .string(detection.state),
            "present": detection.present.map(JSONValue.bool) ?? .null,
            "value": detection.value.map { .string($0.rawValue) } ?? .null,
            "how": detection.detail.map(JSONValue.string) ?? .null,
            "conflict": .bool(card.conflict),
            "report": report.map(Self.json) ?? .null,
            "canAdd": .bool(readiness.answer != nil),
        ]
        if let answer = readiness.answer {
            key["expected"] = [
                "value": .string(answer.value.rawValue),
                "complianceCode": answer.code.map(JSONValue.string) ?? .null,
                "declarationId": answer.declarationID.map(JSONValue.string) ?? .null,
                "buildSettings": .array(answer.buildSettings.map(JSONValue.string)),
                "infoPlist": .string(answer.snippet),
                "settledBy": .string(answer.basis == .confirmed ? "answers" : "build"),
            ]
            key["whyNot"] = .null
        } else {
            key["expected"] = .null
            key["whyNot"] = readiness.reason.map { ["code": .string($0.code), "reason": .string($0.text)] } ?? .null
        }
        key["next"] = .string(Self.next(card))
        return .object(key)
    }

    private static func next(_ card: EncryptionKeyCardModel) -> String {
        if card.conflict {
            return "The key says something else than the settled answer: change it in the project and report it with report_encryption_key."
        }
        if card.isDone {
            if case .inferred = card.detection {
                return """
                Inferred from the uploads only: an answer given for each build in App Store Connect looks the same. In the \
                project, check that the app target has it, add it if not, and report it with report_encryption_key.
                """
            }
            return "Nothing to do: builds uploaded from now on answer the question."
        }
        guard card.readiness.answer != nil else {
            return "Not settled yet: the person answers or confirms the questions on the Export Compliance page first. Don't add the key until then."
        }
        return """
        Suggest Add It to the Project on the Export Compliance page, which starts Claude Code in the app's project. Or, \
        when you're working in the project yourself, add `expected` to the app target (the build settings in every \
        configuration when it generates its Info.plist, else infoPlist in its Info.plist), and report it with \
        report_encryption_key. Never push or upload.
        """
    }

    static func json(_ report: EncryptionKeyReport) -> JSONValue {
        [
            "status": .string(report.status.rawValue),
            "value": report.value.map { .string($0.rawValue) } ?? .null,
            "complianceCode": report.code.map(JSONValue.string) ?? .null,
            "where": .array(report.places.map { place in
                [
                    "file": .string(place.file),
                    "line": place.line.map(JSONValue.int) ?? .null,
                    "buildSetting": place.buildSetting.map(JSONValue.string) ?? .null,
                    "target": .string(place.target),
                    "configurations": .array(place.configurations.map(JSONValue.string)),
                ]
            }),
            "commit": report.commit.map(JSONValue.string) ?? .null,
            "reason": report.reason.map(JSONValue.string) ?? .null,
            "notes": report.notes.map(JSONValue.string) ?? .null,
            "by": .string(report.client),
            "date": .string(report.date.formatted(.iso8601)),
        ]
    }
}
