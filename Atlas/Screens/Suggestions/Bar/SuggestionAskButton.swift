//
//  SuggestionAskButton.swift
//  Atlas
//

import AppKit
import SwiftUI

/// "Ask Claude Code…" in a section's header, or Generate Suggestions… with
/// an API key, or Set Up Assistant…. Atlas starts Claude Code itself
/// once its helper is saved (`ClaudeCodeLauncher`), and otherwise copies the
/// prompt to paste. A started request flies to the toolbar's Assistant
/// button (board 56) and the button says "Claude Code Is Working…" until the
/// suggestions stop coming or the run ends, when the window's toast says
/// where they are. A pasted request ends with the section's toast; while
/// its suggestions arrive the section's banner says so and the button steps
/// aside.
struct SuggestionAskButton: View {
    let appID: StoreApp.ID
    let area: SuggestionArea
    /// Set by the Assistant button's Ask for Suggestions…: asks once shown.
    @Binding var requestsAsk: Bool
    /// The text "Ask …" copies.
    let prompt: () -> String
    /// The page Generate Suggestions… works on with an API key; none where
    /// a key can't suggest anything.
    var generator: (any KeyAssistantGenerating)?
    /// Names the run when Atlas starts Claude Code, and its project
    /// folder's Open panel.
    var appName = ""
    /// The assistant stopped sending: the section shows this in its toast.
    var onRequestFinished: (String) -> Void = { _ in }

    @Environment(MCPServerController.self) private var assistants
    @Environment(FieldSuggestionStore.self) private var suggestions
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(KeyAssistantController.self) private var keyAssistant
    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(\.askCenterOverride) private var askCenterOverride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchor = AskAnchor()
    @State private var showsPopover = false
    @State private var generate: GenerateSuggestionsModel?
    @State private var generation: Task<Void, Never>?

    private var askCenter: AssistantAskCenter { askCenterOverride ?? .shared }

    var body: some View {
        // A stack, so the tasks below keep running while the button is away.
        ZStack {
            if run == nil {
                if let appAsk {
                    busyButton(appAsk)
                } else if streamingRequest == nil {
                    button
                }
            }
        }
        .onChange(of: request?.isReceiving) {
            if request?.isReceiving == true { showsPopover = false }
        }
        .onChange(of: request == nil) {
            if request == nil { showsPopover = false }
        }
        .onChange(of: assistants.isWorking) {
            if !assistants.isWorking, streamingRequest != nil { finishRequest() }
        }
        // A run that failed, or had steps refused with nothing sent, keeps
        // its request for the popover to explain.
        .onChange(of: askRun?.phase) {
            guard let run = askRun, request?.isReceiving == false else { return }
            if run.failure != nil || (run.phase == .finished && !run.denials.isEmpty) { showsPopover = true }
        }
        .task(id: requestsAsk) {
            guard requestsAsk else { return }
            requestsAsk = false
            // The popover needs its button on screen first.
            try? await Task.sleep(for: .milliseconds(300))
            startAsking()
        }
        .task(id: request?.isComplete) {
            guard request?.isComplete == true else { return }
            // Long enough to read "4 of 4" before the toast.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            finishRequest()
        }
    }

    /// The app's request, from this button or another, while it runs.
    private var appAsk: AssistantAsk? { askCenter.ask(for: appID) }

    /// Can't be pressed, but says what's going on at full color.
    private func busyButton(_ ask: AssistantAsk) -> some View {
        Button {} label: {
            AskButtonLabel(title: ask.busyTitle)
        }
        .buttonStyle(AskBusyButtonStyle())
        .disabled(true)
        .accessibilityIdentifier("suggestions.ask")
    }

    private var button: some View {
        Button(action: startAsking) {
            if status.isConnected {
                AskButtonLabel(title: status.askTitle)
            } else {
                Text(status.askTitle)
            }
        }
        .disabled(status.isReady && generator == nil)
        .background(AskAnchorView(anchor: anchor))
        .accessibilityIdentifier("suggestions.ask")
        .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
            if status.isReady, let generate {
                GenerateSuggestionsPopover(model: generate, onGenerate: startGenerating) {
                    showsPopover = false
                    cancelGenerating()
                }
            } else if let request {
                AskAssistantPopover(request: request) {
                    Self.copy(request.prompt)
                } onCancel: {
                    showsPopover = false
                    suggestions.cancelRequest()
                }
            }
        }
    }

    private var status: AssistantStatus { assistants.assistantStatus }

    /// The request for this app and area, if one is open.
    private var request: AssistantSuggestionRequest? {
        guard let request = suggestions.request, request.appID == appID, request.area == area else { return nil }
        return request
    }

    /// Suggest Everything for this app, while it receives.
    private var run: SuggestionRun? {
        guard let run = suggestions.run, run.appID == appID, run.isRunning else { return nil }
        return run
    }

    private var streamingRequest: AssistantSuggestionRequest? {
        request?.isReceiving == true ? request : nil
    }

    private var askPurpose: ClaudeCodeRunPurpose { .ask(area: area.title) }

    /// The run Atlas started for the open request.
    private var askRun: ClaudeCodeRun? {
        guard let request else { return nil }
        return launcher.latestRun(appID: appID, purpose: askPurpose, since: request.startedAt)
    }

    /// Asks the connected assistant, opens Generate Suggestions…, or setup.
    private func startAsking() {
        if status.isConnected {
            ask()
        } else if status.isReady {
            guard generator != nil else { return }
            prepareGenerate()
            showsPopover = true
        } else {
            navigator.isAssistantSetupPresented = true
        }
    }

    /// Starts Claude Code when the helper is saved and sends the request
    /// to the toolbar, else copies the prompt and shows it.
    private func ask() {
        guard case let .connected(client) = assistants.assistantStatus else { return }
        if askRun?.isActive == true || appAsk != nil { return }
        let text = prompt()
        suggestions.beginRequest(appID: appID, area: area, client: client, prompt: text)
        guard launcher.canStart else {
            Self.copy(text)
            showsPopover = true
            return
        }
        let ask = AssistantAsk(appID: appID, client: client, subject: area.title)
        let suggestions = suggestions
        let appID = appID
        let area = area
        let sent = askCenter.send(ask, from: anchor, reduceMotion: reduceMotion) { run in
            Self.ended(run, appID: appID, area: area, suggestions: suggestions)
        }
        guard sent else {
            suggestions.cancelRequest()
            return
        }
        Task {
            if let runID = await launcher.start(askPurpose, appID: appID, appName: appName, prompt: text) {
                askCenter.attach(runID: runID, to: ask.id)
                return
            }
            // No folder chosen, so nothing was asked; or the helper went
            // away, so it's the paste after all.
            askCenter.cancel(ask.id)
            if launcher.canStart {
                suggestions.cancelRequest()
            } else {
                Self.copy(text)
                showsPopover = true
            }
        }
    }

    /// The run of an ask ended, wherever the person is: what it sent ends
    /// the request; the toast's text says where the suggestions are, or
    /// that none came.
    static func ended(_ run: ClaudeCodeRun, appID: StoreApp.ID, area: SuggestionArea, suggestions: FieldSuggestionStore) -> String? {
        guard let request = suggestions.request, request.appID == appID, request.area == area else { return nil }
        if request.isReceiving {
            return suggestions.finishRequest()?.askFinishedText
        }
        switch run.phase {
        case .finished where run.denials.isEmpty:
            suggestions.cancelRequest()
            return String(localized: "\(request.client) finished without sending suggestions.")
        case .finished:
            // Kept for the popover, which lists the refused steps.
            return String(localized: "\(request.client) finished without sending suggestions: some of its steps weren’t allowed.")
        case .failed:
            // Kept for the popover, which says how to get past it.
            return AssistantAskCenter.endingText(run, client: request.client, done: "")
        case .stopped, .starting, .working:
            suggestions.cancelRequest()
            return nil
        }
    }

    /// Opens Generate Suggestions… on what will be sent; one already
    /// waiting for its answer stays.
    private func prepareGenerate() {
        guard generate?.isGenerating != true, let generator else { return }
        let model = GenerateSuggestionsModel(keyAssistant: keyAssistant, generator: generator, suggestions: suggestions, appID: appID, area: area)
        generate = model
        Task { await model.prepare() }
    }

    private func startGenerating() {
        guard let generate else { return }
        generation = Task {
            switch await generate.generate() {
            case .sent, .cancelled:
                showsPopover = false
            case let .nothingNew(text):
                showsPopover = false
                onRequestFinished(text)
            case .failed:
                break
            }
        }
    }

    private func cancelGenerating() {
        generation?.cancel()
        generation = nil
    }

    /// The suggestions stopped coming: an ask ends with the window's
    /// toast, a pasted request with the section's.
    private func finishRequest() {
        guard let finished = suggestions.finishRequest(), finished.isReceiving else { return }
        if let appAsk {
            askCenter.finish(appAsk.id, text: finished.askFinishedText)
        } else {
            onRequestFinished(finished.finishedText)
        }
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
