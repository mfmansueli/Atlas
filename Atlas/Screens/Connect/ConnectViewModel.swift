//
//  ConnectViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// The connect form: Issuer ID, Key ID and the `.p8` key. Each field is
/// checked locally once the person leaves it (`CredentialsValidator`), then
/// "Connect" checks the key with App Store Connect (`KeyChecker`) and only a
/// key that works is handed to `onConnect`, which saves it.
@MainActor
@Observable
final class ConnectViewModel {
    var issuerID = ""
    /// Uppercased as it's typed (`uppercaseKeyID()`).
    var keyID = ""

    private(set) var privateKey: ImportedPrivateKey?
    /// The name of a picked or dropped file that isn't a `.p8` key.
    private(set) var rejectedFileName: String?
    /// Why the last picked or dropped file couldn't even be read.
    private(set) var importErrorMessage: String?
    /// Why the last "Connect" failed (Apple's answer, network, Keychain).
    private(set) var failure: KeyCheckFailure?
    private(set) var isVerifying = false
    /// Fields the person has left at least once; only those show hints.
    private(set) var leftFields: Set<Field> = []

    private let checker: any KeyChecker
    /// The check Connect started, so Cancel can stop it.
    @ObservationIgnored private var connecting: Task<Void, Never>?
    private let onConnect: (AppStoreConnectCredentials, KeyAccessCheck) throws -> Void

    init(
        checker: any KeyChecker,
        privateKey: ImportedPrivateKey? = nil,
        onConnect: @escaping (AppStoreConnectCredentials, KeyAccessCheck) throws -> Void
    ) {
        self.checker = checker
        self.onConnect = onConnect
        if let privateKey { importKey(privateKey) }
    }

    /// A text field of the form, for "validate when it loses focus".
    enum Field: Hashable, Sendable {
        case issuerID
        case keyID
    }

    // An empty field isn't wrong yet, and neither is one still being typed.
    var issuerIDIssue: CredentialsIssue? {
        guard leftFields.contains(.issuerID), !issuerID.isEmpty else { return nil }
        return CredentialsValidator.issuerIDIssue(issuerID)
    }

    var keyIDIssue: CredentialsIssue? {
        guard leftFields.contains(.keyID), !keyID.isEmpty else { return nil }
        return CredentialsValidator.keyIDIssue(keyID)
    }

    // The green check beside each field's name (README-Welcome): shown as
    // soon as the value has the right form, while typing too. Whether Apple
    // takes the key is what Connect asks.
    var issuerIDLooksRight: Bool {
        !issuerID.isEmpty && CredentialsValidator.issuerIDIssue(issuerID) == nil
    }

    var keyIDLooksRight: Bool {
        !keyID.isEmpty && CredentialsValidator.keyIDIssue(keyID) == nil
    }

    /// Only a file that reads as a P-256 private key is kept (`importKey`).
    var keyFileLooksRight: Bool { privateKey != nil }

    var credentials: AppStoreConnectCredentials? {
        CredentialsValidator.credentials(issuerID: issuerID, keyID: keyID, privateKeyPEM: privateKey?.pem)
    }

    var canConnect: Bool { credentials != nil && !isVerifying }

    func leave(_ field: Field) {
        leftFields.insert(field)
    }

    /// Key IDs are capital letters and digits; the view calls this after
    /// each edit, so the field shows the uppercased text while typing.
    func uppercaseKeyID() {
        let uppercased = keyID.uppercased()
        if uppercased != keyID { keyID = uppercased }
    }

    /// A picked or dropped file. Fills in an empty Key ID from the
    /// `AuthKey_<KEYID>.p8` name.
    func importKey(_ key: ImportedPrivateKey) {
        importErrorMessage = nil
        // Another file: the last check's verdict was about the old one.
        failure = nil
        guard CredentialsValidator.privateKeyIssue(key.pem) == nil else {
            privateKey = nil
            rejectedFileName = key.fileName
            return
        }
        privateKey = key
        rejectedFileName = nil
        if keyID.trimmingCharacters(in: .whitespaces).isEmpty, let fromName = KeyFileName.keyID(from: key.fileName) {
            keyID = fromName
        }
    }

    /// The file couldn't even be read (permissions, not UTF-8, …).
    func importFailed(_ error: any Error) {
        importErrorMessage = AppleErrorCopy(String(localized: "The key file couldn’t be read.", comment: "kind:error"), error: error).text
    }

    func removeKey() {
        privateKey = nil
        rejectedFileName = nil
        importErrorMessage = nil
    }

    /// Connect (and Try Again): checks the key in a task Cancel can stop.
    func startConnect() {
        guard canConnect else { return }
        connecting = Task { await connect() }
    }

    /// Cancel while the key is checked: back to the filled form, with no
    /// error, and nothing saved.
    func cancelConnect() {
        connecting?.cancel()
        connecting = nil
    }

    func connect() async {
        guard let credentials, !isVerifying else { return }
        isVerifying = true
        failure = nil
        defer { isVerifying = false }
        do {
            let check = try await checker.check(credentials)
            try Task.checkCancellation()
            try onConnect(credentials, check)
        } catch {
            // Cancelled by the person: not a failure to explain.
            if Task.isCancelled || error is CancellationError { return }
            let failure = KeyCheckFailure(error)
            self.failure = failure
            // The file itself is the problem: Connect waits for another one.
            if failure == .roleTooLow { privateKey = nil }
        }
    }
}
