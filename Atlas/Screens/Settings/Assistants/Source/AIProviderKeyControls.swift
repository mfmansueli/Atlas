//
//  AIProviderKeyControls.swift
//  Atlas
//

import SwiftUI

/// Settings → AI Assistants → "An API key": the provider, the key (kept in
/// this Mac's Keychain) and whether the provider takes it, checked again
/// after a new key or Check Key.
struct AIProviderKeyControls: View {
    @Environment(TranslationPreferences.self) private var preferences
    @State private var keyStatus: AIProviderKeyStatusModel
    @State private var draftKey = ""
    @State private var keyErrorMessage: String?
    /// Bumped by saving a key and by Check Key, to check once more.
    @State private var checkRequests = 0
    @FocusState private var isKeyFocused: Bool

    init(keyStatus: AIProviderKeyStatusModel) {
        _keyStatus = State(initialValue: keyStatus)
    }

    var body: some View {
        @Bindable var preferences = preferences
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Text("Provider and key")
                    .font(.callout.weight(.medium))
                Spacer()
                Picker("Provider", selection: $preferences.vendor) {
                    ForEach(AIProviderVendor.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                SecureField("API key", text: $draftKey, prompt: Text(preferences.hasAPIKey ? "••••••••••••••••••••" : "Paste an API key"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .focused($isKeyFocused)
                    .onSubmit(saveKey)
                    .onChange(of: isKeyFocused) { _, focused in
                        if !focused { saveKey() }
                    }
                    .help(Text("Kept in this Mac’s Keychain"))
                    .accessibilityIdentifier("settings.apiKey")
                Button("Check Key") { checkRequests += 1 }
                    .accessibilityIdentifier("settings.apiKey.check")
            }
            AIProviderKeyStatusLine(status: keyStatus.status) { checkRequests += 1 }
            if let keyErrorMessage {
                InlineMessage.error(keyErrorMessage)
            }
        }
        // A newer check (another vendor, a new key) cancels the one running.
        .task(id: KeyCheckID(vendor: preferences.vendor, request: checkRequests)) {
            await keyStatus.check(preferences)
        }
    }

    /// Saves a typed key; an untouched field keeps the saved one.
    private func saveKey() {
        guard !draftKey.isEmpty else { return }
        do {
            try preferences.saveAPIKey(draftKey)
            draftKey = ""
            keyErrorMessage = nil
            checkRequests += 1
        } catch {
            keyErrorMessage = AppleErrorCopy(String(localized: "The key wasn’t saved to the Keychain.", comment: "kind:error"), error: error).text
        }
    }

    private struct KeyCheckID: Hashable {
        let vendor: AIProviderVendor
        let request: Int
    }
}
