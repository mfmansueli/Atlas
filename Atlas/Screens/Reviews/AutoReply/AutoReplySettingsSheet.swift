//
//  AutoReplySettingsSheet.swift
//  Atlas
//

import SwiftUI

/// Reply Automatically… (board 58 · 2, 7 and 9): draft and tell me, or send
/// the ones allowed by themselves; the ratings and languages that may go
/// out alone, the topics that always wait, the wait before sending, the
/// day's cap, the tone with an example and a signature. On Free it shows
/// what Pro does, with Upgrade…; already on, Save and Turn Off.
struct AutoReplySettingsSheet: View {
    let appName: String
    /// Languages the app's reviews are written in ("de", "ja").
    let languages: [String]
    let isOn: Bool
    let isPro: Bool
    let onSave: (AutoReplyRule) -> Void
    let onTurnOff: () -> Void
    let onUpgrade: () -> Void
    @State private var rule: AutoReplyRule
    @Environment(\.dismiss) private var dismiss

    init(
        appName: String, rule: AutoReplyRule, languages: [String], isPro: Bool,
        onSave: @escaping (AutoReplyRule) -> Void, onTurnOff: @escaping () -> Void, onUpgrade: @escaping () -> Void
    ) {
        self.appName = appName
        self.languages = languages
        isOn = rule.isOn
        self.isPro = isPro
        self.onSave = onSave
        self.onTurnOff = onTurnOff
        self.onUpgrade = onUpgrade
        _rule = State(initialValue: rule)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reply Automatically")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if !isPro { ProChip() }
                Spacer()
            }
            .padding([.horizontal, .top], Spacing.large)
            Form {
                Section {
                    Text("""
                    Atlas checks \(appName)’s reviews hourly while running, even from the menu bar. Replies are in the review’s language \
                    and public, so you choose which go out by themselves.
                    """)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    Picker("When a reply is written", selection: $rule.mode) {
                        ForEach(AutoReplyMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                Text(mode.detail).font(.subheadline).foregroundStyle(Palette.label2)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityIdentifier("autoReply.mode")
                }
                if rule.mode == .sendAllowed { allowedSection }
                Section("How Claude writes") {
                    Picker("Tone", selection: $rule.tone) {
                        ForEach(AutoReplyTone.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("autoReply.tone")
                    TextField("Signature", text: $rule.signature, prompt: Text("Optional, e.g. Ana from Lumen"))
                        .accessibilityIdentifier("autoReply.signature")
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Text("Example, to a 5★ review")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.label2)
                        Text(rule.tone.example(appName: appName, signature: rule.signature))
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.small)
                            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
                            .accessibilityIdentifier("autoReply.example")
                    }
                    Text("""
                    Replies never mention prices, offers, other apps or new-feature dates, or ask for a better rating. A reply that would \
                    waits, with the reason.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                }
                if !isPro {
                    Section {
                        HStack(spacing: Spacing.small) {
                            ProChip()
                            Text(
                                "Automatic replies are part of Pro. Writing or suggesting single replies stays free."
                            )
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityIdentifier("autoReply.free")
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 600, height: 680)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autoReply.sheet")
    }

    private var allowedSection: some View {
        Section("What may go out by itself") {
            LabeledContent("Ratings") {
                HStack(spacing: Spacing.xxSmall) {
                    ForEach(1...5, id: \.self) { stars in
                        Toggle(isOn: binding(stars, in: \.ratings)) {
                            Label("\(stars)", systemImage: "star.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .toggleStyle(.button)
                        .accessibilityLabel(Text(ReviewText.starsSpoken(stars)))
                        .accessibilityIdentifier("autoReply.rating.\(stars)")
                    }
                }
            }
            if languages.count > 1 {
                Toggle("Every language", isOn: Binding { rule.languages.isEmpty } set: { rule.languages = $0 ? [] : Set(languages) })
                    .accessibilityIdentifier("autoReply.everyLanguage")
                if !rule.languages.isEmpty {
                    ForEach(languages, id: \.self) { code in
                        Toggle(ReviewLanguage.name(of: code), isOn: binding(code, in: \.languages))
                    }
                }
            }
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Always waits for you")
                ForEach(AutoReplyTopic.allCases, id: \.self) { topic in
                    Toggle(topic.title, isOn: binding(topic, in: \.waitTopics))
                        .accessibilityIdentifier("autoReply.topic.\(topic.key)")
                }
                Toggle("Any review Claude isn’t sure about", isOn: .constant(true))
                    .disabled(true)
            }
            Picker("Wait before sending", selection: $rule.delay) {
                ForEach(AutoReplyDelay.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("autoReply.delay")
            Stepper(value: $rule.dailyCap, in: AutoReplyRule.dailyCapRange) {
                Text("At most \(rule.dailyCap) a day")
            }
            .accessibilityIdentifier("autoReply.cap")
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            if isOn {
                Button("Turn Off", role: .destructive) {
                    onTurnOff()
                    dismiss()
                }
                .accessibilityIdentifier("autoReply.turnOff")
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            if !isPro {
                Button("Upgrade…", action: onUpgrade)
                    .accessibilityIdentifier("autoReply.upgrade")
            }
            Button(isOn ? String(localized: "Save") : String(localized: "Turn On")) {
                var saved = rule
                saved.isOn = true
                onSave(saved)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isPro || (rule.mode == .sendAllowed && rule.ratings.isEmpty))
            .accessibilityIdentifier("autoReply.save")
        }
        .padding(Spacing.large)
    }

    private func binding<Value: Hashable>(_ value: Value, in keyPath: WritableKeyPath<AutoReplyRule, Set<Value>>) -> Binding<Bool> {
        Binding {
            rule[keyPath: keyPath].contains(value)
        } set: { isOn in
            if isOn { rule[keyPath: keyPath].insert(value) } else { rule[keyPath: keyPath].remove(value) }
        }
    }
}
