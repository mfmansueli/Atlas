//
//  WorkspaceCommands.swift
//  Atlas
//

import SwiftUI

/// Menu bar commands for the main window: sections (⌘1–⌘9) and Refresh (⌘R)
/// in View, a Product menu with Run Autopilot (⌥⌘A, the Autopilot bar's
/// own action), Review & Push (⇧⌘P), Activity and the Autopilot bar's
/// conversation (⌘J), plus the
/// section-specific commands that work through `WorkspaceIntent`. macOS 26
/// draws the symbol of every command with one, so each item with a
/// standard symbol has it (README-DS §13); lists of choices don't.
struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceNavigator) private var navigator

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(AppWorkspaceSection.allCases) { section in
                Button(section.fullTitle, systemImage: section.systemImage) { navigator?.choose(section) }
                    .keyboardShortcut(KeyEquivalent(Character(String(section.shortcutDigit).lowercased())), modifiers: section.shortcutModifiers)
            }
            .disabled(navigator == nil)
            Divider()
            Button("Refresh", systemImage: "arrow.clockwise") { navigator?.refresh() }
                .keyboardShortcut("r")
                .disabled(navigator == nil)
            Divider()
        }
        CommandGroup(after: .textEditing) {
            Button("Find", systemImage: "magnifyingglass") { navigator?.send(.search) }
                .keyboardShortcut("f")
                .disabled(navigator == nil)
            Button("Find and Replace Across Locales…", systemImage: "text.magnifyingglass") { navigator?.open(.storePage, intent: .findAndReplace) }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(navigator == nil)
        }
        CommandMenu("Pricing") {
            Group {
                Button("Review Suggestions", systemImage: "sparkles") { navigator?.open(.subscriptionPricing, intent: .reviewSuggestions) }
                Button("Apply Suggested Prices…", systemImage: "checkmark.circle") { navigator?.open(.subscriptionPricing, intent: .applyRecommendedPrices) }
                Button("Schedule Pending Prices…", systemImage: "calendar.badge.clock") {
                    navigator?.open(.subscriptionPricing, intent: .editPriceSchedule(productID: nil))
                }
                Divider()
                // Its list of displays is a choice: names only.
                Menu("Show Prices As", systemImage: "eye") {
                    ForEach(PricingDisplay.allCases, id: \.self) { display in
                        Button(display.title) { navigator?.open(.subscriptionPricing, intent: .showPrices(display)) }
                    }
                }
                Button("Results", systemImage: "chart.line.uptrend.xyaxis") { navigator?.open(.subscriptionPricing, intent: .showResults) }
            }
            .disabled(navigator == nil)
        }
        CommandMenu("Store Page") {
            Group {
                Button("Translate Missing…", systemImage: "translate") { navigator?.open(.storePage, intent: .translateMissing) }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Import Translations…", systemImage: "square.and.arrow.down") { navigator?.open(.storePage, intent: .importTranslations) }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            .disabled(navigator == nil)
        }
        CommandMenu("Product") {
            Group {
                Button("Run Autopilot", systemImage: "play.circle") { navigator?.requestsAutopilot = true }
                    .keyboardShortcut("a", modifiers: [.command, .option])
                Button("Review & Push…", systemImage: "arrow.up.circle") { navigator?.isReviewPresented = true }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Activity", systemImage: "clock") { navigator?.isActivityPresented = true }
                // Opens and closes the Autopilot bar (board 80).
                Button(String(localized: "Ask Autopilot", comment: "kind:menu-item · opens the Autopilot bar's conversation"), systemImage: "sparkles") {
                    AssistantChatCenter.shared.toggle()
                }
                .keyboardShortcut("j")
            }
            .disabled(navigator == nil)
        }
    }
}
