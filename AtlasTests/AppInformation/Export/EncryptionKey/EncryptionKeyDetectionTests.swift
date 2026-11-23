//
//  EncryptionKeyDetectionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// How Atlas tells, without a run, that builds answer the question
/// themselves: an assistant's report first, then what it read in the
/// project, then the newest uploads (inferred, and never from builds Atlas
/// answered itself). And what the card shows for each.
@Suite("Encryption key detection")
struct EncryptionKeyDetectionTests {
    private static let date = Date(timeIntervalSince1970: 1_795_000_000)

    private static func build(_ number: String, _ flag: Bool?, state: String = "VALID") -> EncryptionKeyBuild {
        EncryptionKeyBuild(id: "b\(number)", number: number, usesNonExemptEncryption: flag, processingState: state)
    }

    private static func report(_ status: EncryptionKeyReport.Status, value: EncryptionKeyValue? = .no) -> EncryptionKeyReport {
        EncryptionKeyReport(
            appID: "1", status: status, value: value,
            places: [.init(
                file: "Lumen.xcodeproj/project.pbxproj", buildSetting: "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption",
                target: "Lumen", configurations: ["Debug", "Release"]
            )],
            commit: "4f2a9c1e7b33", reason: status == .couldNotAdd ? "No target builds dev.example.lumen." : nil,
            client: "Claude Code", date: date
        )
    }

    private static let readyNo = EncryptionKeyReadiness.ready(EncryptionKeyAnswer(value: .no, basis: .confirmed))

    // MARK: - Detection

    @Test func aReportWins() {
        let detection = EncryptionKeyDetection.detect(report: Self.report(.added), project: .notFound(targets: ["Lumen"]), builds: [])
        #expect(detection.state == "reported")
        #expect(detection.present == true)
        #expect(detection.headline == "Added in project.pbxproj (Lumen) — builds uploaded from now on answer it")
        #expect(detection.detail?.contains("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption (Debug, Release) — Lumen") == true)
        #expect(Self.report(.alreadyThere).headline == "Already in project.pbxproj (Lumen) — builds uploaded from now on answer it")
        #expect(Self.report(.added).byLine(.dateTime.year()).contains("By Claude Code"))
        #expect(Self.report(.added).byLine(.dateTime.year()).contains("commit 4f2a9c1e7b"))
    }

    @Test func aFailedReportFallsBackToWhatElseAtlasKnows() {
        let detection = EncryptionKeyDetection.detect(
            report: Self.report(.couldNotAdd, value: nil), project: .noFolder, builds: [Self.build("43", nil)]
        )
        #expect(detection == .missing(build: "43"))
        #expect(detection.present == false)
        #expect(detection.detail == "Build 43 is still waiting for its encryption answer, so the key isn’t in it.")
    }

    @Test func whatTheProjectSaysComesNext() {
        let key = EncryptionKeyProjectState.Key(
            value: .no, target: "Lumen", location: "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption", isBuildSetting: true
        )
        let detection = EncryptionKeyDetection.detect(report: nil, project: .found(key), builds: [Self.build("43", nil)])
        #expect(detection.state == "readInProject")
        #expect(detection.headline == "In Lumen’s build settings — builds uploaded from now on answer it")
        let missing = EncryptionKeyDetection.detect(report: nil, project: .notFound(targets: ["Lumen"]), builds: [Self.build("43", false)])
        #expect(missing == .notInProject(targets: ["Lumen"]))
        #expect(missing.detail?.contains(".xcconfig files aren’t read") == true)
    }

    @Test func uploadsThatArriveAnsweredAreInferredAndSaySo() {
        let builds = [Self.build("45", nil, state: "PROCESSING"), Self.build("44", false), Self.build("43", false), Self.build("42", nil)]
        let detection = EncryptionKeyDetection.detect(report: nil, project: .noFolder, builds: builds)
        #expect(detection == .inferred(value: .no, builds: ["44", "43"]))
        #expect(detection.state == "inferred")
        #expect(detection.headline == "Builds already answer it")
        #expect(detection.detail?.contains("Builds 44 and 43 arrived with the encryption answer already set") == true)
        #expect(detection.detail?.contains("this is inferred") == true)
    }

    @Test func buildsAtlasAnsweredItselfDontCount() {
        let change = PendingChange(
            id: "c", appID: "1", section: .appInformation, group: "g", title: "t", oldValue: "", newValue: "",
            source: .you, requests: [AppInformationChangeBuilder.patch("builds", id: "b44", attributes: ["usesNonExemptEncryption": .bool(false)])]
        )
        let record = PushRecord(date: Self.date, appID: "1", appName: "Lumen", title: "t", pushed: [change])
        let answered = EncryptionKeyDetection.answeredInAtlas([record])
        #expect(answered == ["b44"])
        let detection = EncryptionKeyDetection.detect(
            report: nil, project: .noFolder, builds: [Self.build("44", false), Self.build("43", false)], answeredInAtlas: answered
        )
        #expect(detection == .unknown)
        #expect(EncryptionKeyDetection.detect(report: nil, project: .unknown, builds: []) == .unknown)
    }

    // MARK: - The card

    @Test func aSettledAnswerOffersAddItToTheProject() {
        let card = EncryptionKeyCardModel(readiness: Self.readyNo, detection: .unknown, shownValue: .no)
        #expect(!card.isDone)
        #expect(card.showsButton)
        #expect(card.buttonTitle == "Add It to the Project…")
        #expect(card.disabledReason == nil)
        #expect(card.snippet == InfoPlistKeyCard.snippet)
        #expect(card.buildSetting == "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO")
    }

    @Test func anUnsettledAnswerSaysWhyTheButtonIsOff() {
        let card = EncryptionKeyCardModel(readiness: .blocked(.unconfirmedSuggestion(client: "Claude Code")), detection: .unknown, shownValue: .no)
        #expect(card.showsButton)
        #expect(card.disabledReason?.contains("Claude Code") == true)
    }

    @Test func aReportedKeyIsDoneWithoutAButton() {
        let card = EncryptionKeyCardModel(readiness: Self.readyNo, detection: .reported(Self.report(.added)), report: Self.report(.added), shownValue: .no)
        #expect(card.isDone)
        #expect(!card.showsButton)
        #expect(card.problem == nil)
    }

    @Test func aFailedRunOffersTryAgainWithItsReason() {
        let failed = Self.report(.couldNotAdd, value: nil)
        let card = EncryptionKeyCardModel(readiness: Self.readyNo, detection: .unknown, report: failed, shownValue: .no)
        #expect(card.buttonTitle == "Try Again")
        #expect(card.problem == "Claude Code couldn’t add it: No target builds dev.example.lumen.")
    }

    @Test func anInferredKeyIsDoneButCanBeChecked() {
        let card = EncryptionKeyCardModel(readiness: Self.readyNo, detection: .inferred(value: .no, builds: ["44"]), shownValue: .no)
        #expect(card.isDone)
        #expect(card.showsButton)
        #expect(card.buttonTitle == "Check in the Project…")
    }

    @Test func aKeyThatSaysSomethingElseIsAConflict() {
        let card = EncryptionKeyCardModel(readiness: .blocked(.needsApprovedDeclaration), detection: .reported(Self.report(.added)), shownValue: .yes)
        #expect(card.conflict)
        #expect(!card.isDone)
        #expect(card.buttonTitle == "Change It in the Project…")
        #expect(card.conflictText?.contains("The key says NO") == true)
    }
}
