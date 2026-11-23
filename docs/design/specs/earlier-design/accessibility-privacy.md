ATLAS · APP INFORMATION · ACCESSIBILITY AND APP PRIVACY · OCTOBER 2026

# Accessibility and App Privacy

Two pages in App Information (⌘4). Accessibility Nutrition Labels are real App Store Connect data: read, edited and published through Review & Push. The App Privacy questionnaire has no API, so it’s a worksheet that an assistant helps fill from the code, followed by a guided checklist for App Store Connect.

**On the canvas.** *Prototype — Accessibility & App Privacy* sits beside the screenshots prototype; its Prototype pill restarts each flow. Boards 15–16 embed it at every state in light and dark. *Components — accessibility & app privacy* holds the new components. This App Privacy page replaces the one in the first addendum: its draft → confirmed → entered states become *Not started → In progress → Done → Marked published → Out of date*.

## 1 · The asymmetry

|  | Has an API? | In Atlas | Reaches Apple through |
| --- | --- | --- | --- |
| **Accessibility declarations** | Yes: `accessibilityDeclarations` | Cards, editor, live vs. draft | Review & Push, with a Publish option per device |
| **Accessibility URL** | Yes, one per app | Field on the Accessibility page | Review & Push |
| **App Privacy questionnaire** | **No** | A worksheet with assistant suggestions, a label preview and a checklist | The person, in App Store Connect, step by step. Atlas never reads or writes it. |
| **Privacy Policy URL, User Privacy Choices URL** | Yes, per locale (app-level localizations) | Privacy URLs tab; the same fields as Store Page’s app-level fields | Review & Push |

The UI says this where it matters. App Privacy carries a quiet “A worksheet, not a sync” banner. The review sheet says the questionnaire isn’t there. The page shows no “synced” or “last fetched” state. The only date is the one the person records with *Mark as Published in App Store Connect*.

## 2 · Where they live

- App Information’s page column now reads *General · Age Rating · Accessibility · App Privacy · App Review · Export Compliance*. Each row shows a one-line status, plus a blue dot for unpushed changes.
- Overview gains three cards:
  - **Accessibility:** state per device, e.g. “iPhone Published · iPad Draft · Apple Watch Not declared · Apple Vision Pro Draft, no live version”.
  - **App Privacy:** worksheet status, open questions, the date it was marked published, the last scan, and “Out of date” when it applies.
  - **Privacy URLs:** coverage across the 39 locales.

## 3 · Accessibility

### Cards, one per device family the app supports

Lumen supports iPhone, iPad, Apple Watch and Apple Vision Pro, so Mac and Apple TV don’t appear. Each card has:

- a state badge;
- “Supports accessibility features: Yes/No”;
- the declared features as compact pills, blue when they aren’t published yet;
- a **Live now → after publishing** box when a published declaration has a draft or unpushed edits;
- a one-line note;
- Edit… / Declare…, **Copy from iPhone**, and **Delete Draft** (drafts only).

| State | When | Badge |
| --- | --- | --- |
| Not declared | No declaration for the device | outlined |
| Draft | Saved in App Store Connect, not on the product page | neutral |
| Draft · can’t publish yet | The device has no live version (Apple Vision Pro, new in 1.4) | neutral, with the reason |
| Published | On the product page | green text |
| Published · changes waiting | A newer draft or local edits exist | neutral, plus the diff |
| Replaced | An older published declaration | not on the cards; kept in Activity |

Also designed: loading (skeleton cards), API error (Apple’s code and request, Try Again), and the never-declared empty state. That state explains the labels and that Apple has said they’ll be required for new apps and updates.

### Editor

- A sheet, 640 pt wide. First: “Does your app support any of these features on iPhone?” Yes/No. No hides the checklist and says what the product page will show.
- The checklist covers only the features that exist on the platform. Voice Control is hidden on watchOS and tvOS, and Larger Text on macOS; one line says why. Each row has the name, a one-line meaning, and **Criteria ↗** linking to Apple’s evaluation criteria for that feature.
- The bar, stated above the list: check a feature only if people can complete the app’s common tasks with it. For Lumen: writing an entry, finding one, reading the weekly reflection, unlocking. Calling an API somewhere isn’t enough.
- Against a published declaration, rows show *Live*, *Adds* or *Removes*.
- **Copy from iPhone** fills another family and drops what isn’t available there, e.g. “Voice Control isn’t available on Apple Watch, so it was left out”. The toast asks you to check the answers on that device.
- Assistant suggestions (`propose_accessibility_declaration`) appear as a CC tag on a feature with low or medium confidence, plus “Code alone can’t prove support; check it with the feature on.” They are never high.

### Review & Push

- One row per device: old → new. Under it, **Publish to the App Store**, on by default when the device has a live version. When it’s off, the declaration is only saved as a draft.
- For a device with no live version the switch is disabled, with the reason: “Apple Vision Pro has no live version yet, so this is saved as a draft. Publish it after 1.4 is released.”
- The footer counts what publishes immediately. Progress per row: *Queued → Sending… → Publishing… → Published*, or *Saved as a draft*.
- **API mapping.** Saving creates or updates the family’s draft in `accessibilityDeclarations` (`deviceFamily`, `supportsVoiceover`, `supportsVoiceControl`, `supportsLargerText`, `supportsSufficientContrast`, `supportsDarkInterface`, `supportsDifferentiateWithoutColorAlone`, `supportsReducedMotion`, `supportsCaptions`, `supportsAudioDescriptions`), then publishes it. Check the exact publish call against Apple’s API reference before building.
- **Rules:**
  - Only drafts can be deleted.
  - Publishing replaces the published declaration, which becomes `REPLACED`.
  - Publishing is immediate but can take up to 24 hours to show everywhere.

### Accessibility URL

One optional field per app, not localized, validated as a full https address. It goes through Review & Push and appears on every device except Apple TV.

## 4 · App Privacy

### Tabs

*Worksheet* · *Fill in App Store Connect* · *Privacy URLs*, plus Export… and the status pill.

### Starting points

- **Scan with an assistant**, the main path:
  - the MCP connection status;
  - when no assistant is connected, the `claude mcp add` command for Lumen’s folder;
  - a ready prompt naming the app and bundle ID, with Copy Prompt;
  - “Waiting for Claude Code to start the scan…” until the first call arrives.
- **Start from scratch**, **Import from fastlane** (`app_privacy_details.json`, with a preview before importing), or **Enter what’s in App Store Connect** by hand. The last exists because Atlas can’t read the current answers.

### Worksheet

- The first question: “Do you or your third-party partners collect data from this app?” Yes/No, with its source tag.
- **Open questions** sit on top, highlighted until answered. Each names the data types it affects and what each answer changes. The worksheet isn’t *done* while any is open.
- **Filters:** All · Unreviewed · Low confidence · Open questions. **Accept All High-Confidence** skips rows that conflict with yours. A toggle shows all 35 types.
- **Categories → data-type rows.** Each row has:
  - Collected / Not collected;
  - the six purposes as toggles;
  - Linked to the user, and Used for tracking;
  - a source tag (You, or CC Claude Code);
  - a status: Unreviewed (purple, the app’s unreviewed color), Accepted, Edited by you, or Suggestion rejected;
  - a confidence badge with three bars, neutral;
  - the assistant’s one-line rationale;
  - **Evidence · n**;
  - Accept / Reject.A collected type with no purpose is flagged.
- **Evidence popover:** the suggested answer, the rationale, and each evidence item with its kind (SDK privacy manifest, Dependency, Info.plist, Entitlements, Code). An item is either an SDK, version and manifest entry, or a file:line with a short excerpt. Any open question for the row is shown too.
- **Conflicts:** when a suggestion differs from an answer you gave, the row shows both: Keep yours or Use Claude Code’s.
- **Cross-check:** a manifest that declares a type the worksheet says isn’t collected shows a warning, e.g. “Sentry 8.36.0’s privacy manifest declares Other Diagnostic Data, but the worksheet says it isn’t collected”. The actions are Mark as Collected, or Not Collected, Explain….
- **Later scans** show what changed since the previous one: SDKs added or removed, answers changed or unchanged. New suggestions arrive unreviewed.
- **Scan summary** popover:
  - the assistant;
  - repository and commit;
  - when it ran;
  - the SDKs found;
  - the manifests read;
  - tracking signals: `NSPrivacyTracking`, `NSUserTrackingUsageDescription`, `ATTrackingManager`, `ASIdentifierManager`;
  - what it couldn’t see: your servers.
- **Label preview** (inspector): the product page label in Apple’s three groups. *Data Used to Track You*, *Data Linked to You* and *Data Not Linked to You* list categories with their types, or *Data Not Collected*. Unreviewed suggestions are left out.
- A quiet disclaimer: suggestions aren’t legal advice; the developer is responsible, including for what third-party SDKs collect; and Apple’s definition of “collect”.

### Fill in App Store Connect

- A column of at most 520 pt, so Atlas fits beside Safari. **Open App Store Connect ↗** goes to the app’s App Privacy page. **Tile with Safari** uses macOS window tiling.
- Steps in the order App Store Connect asks:
  1. the first question;
  2. the data types by category;
  3. for each type: purposes, then linked, then tracking;
  4. Publish.Each step has a checkbox and Copy with plain text.
- The checklist is blocked, with the reasons, until the worksheet is done.
- **Mark as Published in App Store Connect** is enabled when every step is checked. It stores the date and a snapshot of the reviewed answers. When a later edit or scan makes them differ, or leaves unreviewed suggestions, the page shows *Out of date with App Store Connect* and points back to the checklist.
- **Export:** fastlane’s `app_privacy_details.json` (categories, purposes and data protections in fastlane’s keys), or a readable summary as Markdown or PDF. The summary includes the rationale and the answered questions.

### Privacy URLs

A table of the 39 locales: Privacy Policy URL (required) and User Privacy Choices URL (optional), with coverage, validation, unpushed dots and *Fill Missing from English (U.S.)*. These are the Store Page’s app-level fields. Each page links to the other, and edits go through Review & Push.

## 5 · Apple’s questionnaire, as modelled

16 categories, 35 data types, with Apple’s exact names: Contact Info (Name, Email Address, Phone Number, Physical Address, Other User Contact Info) · Health & Fitness (Health, Fitness) · Financial Info (Payment Info, Credit Info, Other Financial Info) · Location (Precise Location, Coarse Location) · Sensitive Info · Contacts · User Content (Emails or Text Messages, Photos or Videos, Audio Data, Gameplay Content, Customer Support, Other User Content) · Browsing History · Search History · Identifiers (User ID, Device ID) · Purchases (Purchase History) · Usage Data (Product Interaction, Advertising Data, Other Usage Data) · Diagnostics (Crash Data, Performance Data, Other Diagnostic Data) · Surroundings (Environment Scanning) · Body (Hands, Head) · Other Data (Other Data Types).

Purposes: Third-Party Advertising, Developer’s Advertising or Marketing, Analytics, Product Personalization, App Functionality, Other Purposes. Per collected type: linked to the user’s identity, and used for tracking. The answers are per app, not per version.

## 6 · MCP contract

Same pattern as the other tools. Reads are always allowed while the server runs. `propose_*` needs the “Propose app information” permission and returns, per item, `queued`, `conflict`, `unchanged` or `refused`, with a reason the assistant can act on. Nothing is pushed, and no tool touches App Store Connect’s questionnaire.

### `get_privacy_questionnaire(app)`

```
{ "app": "dev.northpier.lumen",
  "definitions": { "collect": "Data transmitted off the device and kept longer than needed to serve the request in real time…",
                   "linked": "…", "tracking": "…", "optionalDisclosure": ["…"] },
  "categories": [ { "id": "identifiers", "name": "Identifiers",
                    "types": [ { "id": "userId", "name": "User ID" }, { "id": "deviceId", "name": "Device ID" } ] }, … ],
  "purposes": [ "THIRD_PARTY_ADVERTISING", "DEVELOPERS_ADVERTISING", "ANALYTICS",
                "PRODUCT_PERSONALIZATION", "APP_FUNCTIONALITY", "OTHER_PURPOSES" ],
  "worksheet": { "collects": true, "answers": [ … ], "openQuestions": [ … ], "lastScan": { … } } }
```

### `propose_privacy_answers(app, scan, answers, open_questions)`

```
{ "app": "dev.northpier.lumen",
  "scan": { "repository": "northpier/lumen", "commit": "4f2c91a", "ranAt": "2026-10-26T10:42:00Z",
            "assistant": "Claude Code",
            "sdks": [ { "name": "RevenueCat", "version": "5.14.2" }, { "name": "Sentry", "version": "8.36.0" }, … ],
            "manifestsRead": [ "Lumen/PrivacyInfo.xcprivacy", "RevenueCat/PrivacyInfo.xcprivacy", … ] },
  "collects": { "value": true, "confidence": "high" },
  "answers": [
    { "dataType": "purchases", "collected": true, "purposes": ["APP_FUNCTIONALITY"],
      "linked": true, "tracking": false, "confidence": "high",
      "rationale": "RevenueCat sends receipts to its servers and keeps purchase history per app user ID.",
      "evidence": [
        { "kind": "sdk_manifest", "sdk": "RevenueCat", "version": "5.14.2",
          "entry": "NSPrivacyCollectedDataTypePurchaseHistory" },
        { "kind": "code", "path": "Lumen/Paywall/PaywallModel.swift", "line": 88,
          "excerpt": "try await Purchases.shared.purchase(package: package)" } ] },
    { "dataType": "photos", "collected": false, "confidence": "high",
      "rationale": "Photos are saved to the user’s private iCloud database, which you can’t read.",
      "evidence": [ { "kind": "info_plist", "path": "Lumen/Info.plist", "line": 31, "excerpt": "NSPhotoLibraryUsageDescription" } ] } ],
  "open_questions": [
    { "id": "q1", "question": "Does your support backend keep the email address after it replies?",
      "affects": ["email", "support"] } ] }
```

Response, per answer:

```
{ "results": [
    { "dataType": "purchases", "status": "queued" },
    { "dataType": "deviceId", "status": "conflict", "yours": { "linked": true }, "reason": "The person answered this; they’ll pick one." },
    { "dataType": "crash", "status": "unchanged" },
    { "dataType": "fingerprint", "status": "refused", "reason": "Unknown data type “fingerprint”. Use an id from get_privacy_questionnaire." },
    { "dataType": "email", "status": "refused", "reason": "Purpose “SUPPORT” isn’t one of Apple’s six. Did you mean APP_FUNCTIONALITY?" } ],
  "openQuestions": "queued" }
```

Evidence kinds: `sdk_manifest`, `dependency` (Package.resolved, Podfile.lock, Cartfile.resolved), `info_plist`, `entitlement`, `code`. Code evidence covers network requests carrying user fields, sign-up and account forms, analytics events, ATT and IDFA, and receipts sent to a backend. A collected answer with no purpose, or `tracking: true` with no tracking evidence and confidence high, is refused with the reason.

### `propose_accessibility_declaration(app, device_family, features, evidence)` · optional

```
{ "app": "dev.northpier.lumen", "deviceFamily": "APPLE_WATCH",
  "features": { "supportsSufficientContrast": { "value": true, "confidence": "medium" },
                "supportsDarkInterface": { "value": true, "confidence": "medium" } },
  "evidence": [ { "kind": "code", "path": "LumenWatch/Theme.swift", "line": 14,
                  "excerpt": "Color(\"Ink\") // asset with Increase Contrast variant" } ] }
```

Confidence is capped at medium: code shows intent, not that people can finish a task with the feature. A feature the platform doesn’t have (Voice Control on watchOS) is refused with that reason.

## 7 · Decisions the brief left open

- **App Privacy is a page with three tabs**, not three pages, so worksheet, checklist and URLs stay one place in the page column.
- **Unreviewed suggestions don’t count**: not in the label preview, the checklist, the export or the published snapshot.
- **Open questions block “done”**, as asked. Answering one applies its effect to the affected rows and says what changed.
- **A rejected suggestion becomes “not collected, yours”**, so the cross-check can still catch a manifest that disagrees.
- **“Out of date”** also triggers on unreviewed suggestions after the marked date, not only on changed answers. A new SDK is news even before review.
- **Publish is per device, on by default for live devices**, and disabled with the reason otherwise. The Vision Pro case shows it.
- **Delete Draft is a pending change too**, like every write.
- **Confidence and the assistant tag are neutral**; purple only marks unreviewed rows. No new tokens.
- **Lumen’s scan** found 14 SDKs and 6 manifests. Journal entries and photos live in the user’s private iCloud database, so they aren’t collected. Support email and Crashlytics linking depend on the backend, so they became open questions.
- Atlas doesn’t automate App Store Connect’s web pages. It guides; the person enters and publishes.

## 8 · SwiftUI notes

- The page column is a `List` with selection; the worksheet is a `List` with sections. The label preview is an `.inspector` that collapses below 1000 pt of content width.
- Purpose toggles are `Toggle(isOn:).toggleStyle(.button)` in a flow layout.
- The evidence popover is a `.popover` with selectable text. File:line items open in Xcode with `xed --line` when the repo is on this Mac.
- Tiling with Safari uses the window tiling API on macOS 15 and later. Opening the exact App Privacy page needs the app’s Apple ID in the URL.
- Copy buttons put plain text on the pasteboard, never rich text, so pasting into App Store Connect’s fields is clean.

Sample data is illustrative: Lumen’s SDKs, versions, file paths, scan results and dates. Feature names, states and the questionnaire’s categories, types and purposes follow Apple’s documentation.

References: [Manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels) · [Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels) · [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/).
