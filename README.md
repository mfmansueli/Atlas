# Atlas

macOS app (SwiftUI, macOS 27+) for localizing apps faster through the App Store Connect API:

- **Pricing:** per-territory prices for every subscription and in-app purchase, from one base price. Custom prices,
  scheduled changes, the map and the histogram, and the results of past changes.
- **Store page:** the App Store listing's text in every locale, with import, Find and Replace, and translation by Apple
  Translation, an AI provider (Anthropic or OpenAI, with your own API key) or your assistant.
- **Screenshots (⌘3):** an App Store preview of the live set or the new one, per device, language and appearance;
  one template, captions per locale, imported captures (the Captures tab lists each locale's; a click shows one large,
  ← → step through its screens and ↑ ↓ through the locales), and renders checked for fit before they're pushed. The
  template gallery (Templates…) offers 12 templates in four styles (Simple, Bold, Elegant, Playful): angled and leaning
  devices, a caption below the device, uppercase, an emphasized first or last line, highlight bars, a slot's own
  background, and decorations per slot (shapes, rating laurels and badges). Their fonts are bundled (SIL Open Font
  License, `Resources/Fonts`), so a template looks the same on every Mac. A laurel or badge must be true: before a
  push, its number is checked against the app's App Store rating in each locale's country (the iTunes Lookup API),
  and a higher one, or one before the app has a rating there, fails the render. Review &
  Push uploads them, keeps the screenshots they replace on this Mac, and Activity puts those back. A live screenshot
  with no image in App Store Connect (its upload never finished, or Apple couldn't process it) has nothing to keep and
  is replaced anyway; one still processing is left for a later push. An empty set App Store Connect already has
  (an upload that never finished) is filled instead of created again, which Apple refuses as "Screenshot Set Already
  Exists"; if a create is refused anyway, the push looks the set up and fills it while it's empty. Each image's
  percentage follows the bytes sent (`UploadProgressDelegate`), not just its parts. **Screenshot
  Autopilot** plans the screens, has a connected assistant (Claude Code, Cursor or Codex) capture them in Simulator in
  every language, lets you pick the best captures, gets three design directions (from Claude Design, a Figma file, a
  brand folder or Atlas's starters), then localizes and checks every caption; the new set waits in Review &
  Push. Once the assistant reports the Xcode project (`report_app_support`), or App Store Connect shows it (a build
  with a watch app, from the build's icons; a visionOS version), the plan covers every device the app runs on, iPhone, iPad, Apple Watch (the watch app's own screens, no captions) and Apple Vision Pro (windows of the
  same moments as iPhone, under their captions, pushed to the visionOS version), and every language its string
  catalogs have, including the ones the App Store page doesn't have yet. Unless you keep your own screens, the
  assistant reads the project and picks the screens that show the app best before capturing. **iPhone Duo** (the
  foldable; Apple requires its screenshots from April 2027 for apps built with the iOS 27.1 SDK) is a third set the
  template renders, beside iPhone and iPad, with the same slots and captions, at its inner display's 2007 × 2853
  (`APP_IPHONE_DUO`, not in Apple's published API spec yet). Its cells stay empty, and nothing is pushed, until it has
  captures. App Store Connect's iPhone Duo set takes both displays' sizes (2007 × 2853 and 1398 × 2034, either way
  up), so either display's captures go in; full bleed, an outer-display capture is flagged as scaled too much, and
  Autopilot asks for the inner display's. Atlas treats it as required already: the Sets menu lists it with the
  sizes Apple requires, and every Autopilot plan has it (turned off, it's left to upload by hand). Before capturing,
  the assistant sets Apple's 9:41 status bar on Wi-Fi with no carrier, light appearance, grants the app's permissions
  (`xcrun simctl privacy grant all`) and answers any other prompt, so no alert lands in a capture; each language
  launches in iOS's own language code and its App Store country's formats (`-AppleLanguages (nb) -AppleLocale nb_NO`),
  with its sample data (entries, names, places) in that language too. Atlas reads the text in every capture as it
  arrives (Vision, then Natural Language for the language): one that reads as English or the primary language instead
  of its own, labels cut off with an ellipsis beyond the primary language's, or the app's name in quotes (a permission
  prompt) comes back to the assistant in `report_capture` with what to fix, and a clean attempt ranks above it. The
  ones the set still uses are listed at Pick and Ready as captures to check. The design AI still designs once, from the
  primary language's picks and every language's captions; Atlas renders each language with its own captures.
  Each device's canvas turns the way its captures are (`AutopilotLocalizer.canvas(_:matching:)`): the iPhone Duo
  simulator's inner display captures landscape, 2853 × 2007, so Duo's canvas is landscape too, in the brief and in
  the set Localize renders, instead of cropping every capture into a Wrong size render. A template with no Duo
  orientation of its own (one made before) lies each Duo render the way its capture does (`TemplateCanvas.following`),
  in the renders, their checks and render keys, the template editor and the MCP measurements.
- **Analytics (⌘8):** the funnel from impression to paid subscriber (impressions → product page views → first-time
  downloads → trial starts → paid starts) for the last 7, 28 or 90 days against the days before, the same funnel broken
  down by territory, language, source, device and product page, findings that open the section where the fix is made,
  the before-and-after of what was pushed from Atlas, and subscriptions. See [Analytics](#analytics).
- **App Information:** general information, the age rating, accessibility declarations and an App Privacy worksheet.
- **In-App Events (⌘4):** each event's name, short and long description in every language, with the languages an
  assistant suggested, a preview of the card, and new events. See [In-App Events](#in-app-events).
- **Submit for Review and release:** Overview's version card says what goes to App Review and what's missing; the
  Submit sheet picks the build, checks What's New in every language, answers encryption and chooses how the version
  is released; afterwards the card follows App Review and the phased release. See
  [Submit for Review and release](#submit-for-review-and-release).
- **Ratings & Reviews (⌘7):** the written reviews from every country, translated on this Mac, each with a reply an
  assistant suggested in the reviewer's language; one message per language for a whole group of reviews; Reply
  Automatically (Pro); and the ratings since the newest version. See [Ratings & Reviews](#ratings--reviews).
- **Navigation:** the sections are in the sidebar (Overview ⌘1 · Store Listing: Store Page ⌘2, Screenshots ⌘3, In-App
  Events ⌘4, App Information ⌘5, Pricing ⌘6 · After Release: Reviews ⌘7, Analytics ⌘8), the apps in a menu at its
  top, and the version's status at its bottom. See [Navigation](#navigation).
- **AI assistants (optional):** a local MCP server lets Claude Code, Claude Desktop, Cursor or Codex read the
  listing and propose text, prices, privacy answers and screenshots. Proposals wait for review like any other change;
  assistants can't push. With a small helper saved once, Atlas starts the person's own Claude Code itself, so
  nothing needs pasting.

It works with a team API key. The design brief for the full feature set is in `DESIGN_PROMPT.md`.

## Connecting an API key

1. In App Store Connect, open **Users and Access → Integrations → App Store Connect API → Team Keys**.
2. Generate a key with the **Admin** or **App Manager** role. Prices and metadata can't be edited with less.
3. In the app, enter the **Issuer ID** and **Key ID**, then drop in the downloaded `AuthKey_<KEYID>.p8`. The Key ID fills itself in from the file name.

"Connect" signs one `GET /v1/apps?limit=1` before saving anything. The key is stored as one generic-password item in the login Keychain (`KeychainCredentialsStore`). Every request carries a freshly signed ES256 JWT (`AppStoreConnectJWT`), so the `.p8` itself never leaves the Mac. Remove the key in Settings → Account.

The sidebar names the team the way its certificates do: the API has no endpoint for a team's name, but every certificate's subject carries it as the organization (`GET /v1/certificates`). A key whose role can't read certificates shows "App Store Connect team"; renaming the key in Settings → Account always wins. Each app's icon is the one App Store Connect took from its latest build (`iconAssetToken` on `GET /v1/builds`); an app with no processed build keeps its letter. A Mac build's icon comes inside the transparent margin of the Mac's icon grid, which is trimmed (`AppIconMargin`) so every icon fills its tile.

## Architecture

It follows Bruma's patterns (`~/Projects/ios/Bruma`).

- **Folders:**
  - `SupportFiles/`: the app entry point and assets.
  - `Managers/`: shared services: the App Store Connect client, the credentials store and `AppSession`.
  - `Models/`: shared models.
  - `Screens/<Feature>/`: the view and view model, plus `Model/` (pure logic and the services protocol), `Services/` (live implementations) and `Components/`.
  - `DesignSystem/`: tokens (`Palette`) and shared components.
  - `Debug/`: DEBUG-only scenes and fakes.
- `MCPBridge/`: the `atlas-mcp` command-line tool (see [AI assistants](#ai-assistants-mcp)). `Sources/` is
  compiled into the tool and the unit tests, and `Tool/main.swift` only into the tool.
- **One top-level type per file.** Extensions go in `Type+Topic.swift`.
- **State:** `@MainActor @Observable final class` view models with `private(set)` state.
  - Each feature talks to the outside world through a `@MainActor protocol <Feature>Services` with a `Live…` implementation. Tests and DEBUG scenes swap in fakes.
  - Views have two inits: a live one, and `init(viewModel:)` for previews and DEBUG scenes.
- **API client:** `AppStoreConnectClient` builds URLs, signs requests, maps HTTP errors (`AppStoreConnectError`) and follows `links.next` pagination. Each resource's endpoints go in their own extension, e.g. `AppStoreConnectClient+Apps.swift`. Requests go through `HTTPTransport`, so unit tests never reach Apple.
- **Swift 6** language mode, strict concurrency, nonisolated by default (like Bruma).

### DEBUG scenes

In a Debug build, launch with `-AtlasDebugScene <id>` to open one state with canned data. A scene never contacts
App Store Connect or the Keychain, and the MCP server in a scene never opens a port (except `cc-live`, below). Each area keeps its ids in its own
`*DebugScenes` type, and `Debug/DebugSceneView.swift` routes them:

- **Library and overview:** `apps`, `apps-empty`, `apps-error`, `lib-loading`, `overview`, `overview-keep`.
- **Navigation** (`NavigationDebugScenes`): a section selected in the sidebar, `nav-ov`, `nav-sp`, `nav-ev`, `nav-rv`,
  `nav-an`; the app menu open, `nav-apps`; the footer following a phased release, `nav-ph`; Free, `nav-free`; the
  sidebar hidden, with the toolbar's section menu and title, `nav-s`, and that menu open, `nav-s-menu`; the other
  sections read ahead while Overview shows, the Store Page and App Information four seconds slow, `nav-prefetch`.
- **Ratings & Reviews** (`ReviewsDebugScenes`; "today" is Nov 16, 2026): `rv`, every review `rv-all`, Show Original
  `rv-orig`, editing a reply `rv-edit`, one sent `rv-sent`, Reply to All `rv-bulk`, Free `rv-free`, the sidebar hidden
  `rv-s`, no suggestions yet `rv-none`, no reviews `rv-empty`, `rv-error`, `rv-loading`, a reply Apple refuses
  `rv-refused`, a language to download `rv-download`, and the overview's card `rv-overview`. Reply Automatically
  (`AutoReplyDebugScenes`): on `ar`, no reply sent by hand yet `ar-first`, paused `ar-paused`, its settings `ar-settings`
  / `ar-settings-on` / Free `ar-free`, History `ar-history`; the menu bar's Pause Auto-Reply `mb-autoreply`.
- **Submit for Review and release** (`ReleaseDebugScenes`, on Overview): before submitting `rel-prep`; the sheet
  `rel-sheet`, with changes to push `rel-sheet-push`, ready `rel-sheet-ok`; then `rel-wait`, `rel-review`,
  `rel-pending`, `rel-phased`, `rel-paused`, `rel-rejected`, `rel-live`, and writes Apple refuses, `rel-refused`.
- **In-App Events** (`InAppEventsDebugScenes`): an event in German `ev`, Portuguese `ev-br`, Arabic `ev-ar`, English
  `ev-en`; every language accepted `ev-done`; the event that goes with the version `ev-mood`; an ended one
  `ev-ended`; `ev-new`, `ev-empty`, `ev-error`.
- **Event artwork** (`EventArtworkDebugScenes`, board 47; Claude Code never starts): the Brief `ea-brief`, with words
  and motion `ea-brief-opts`, without a design project `ea-brief-nods`; drawing `ea-making`, changing one `ea-redo`,
  hidden `ea-hidden`, ready `ea-ready`; `ea-choose`; Check `ea-check`, in German `ea-check-de`, Arabic `ea-check-ar`,
  the light concept `ea-check-b`, the busy one `ea-check-c`, asking `ea-ask`, moving `ea-motion`, the person's files
  `ea-files`; in Review & Push `ea-used`; Free `ea-free`.
- **Connect:** `connect`, `connect-key`, `connect-checking`, `connect-401`, `connect-403`, `connect-rejected`,
  `connect-offline`, `sync`, and more (`ConnectDebugScenes`).
- **Settings (board 48):** `set-general` (`set-general-login`), `set-accounts` (also `set-account`),
  `set-accounts-remove` (Remove… asked in place), `set-suggestions`, `set-pricing`, `set-shots`, `set-notif`,
  `set-notif-blocked`, `set-pro` (yearly), `set-free`, `set-privacy`. AI Assistants: `set-assistants` (an assistant
  connected), `set-assistants-off`, `set-assistants-key` (an API key; `set-translation`, and
  `set-translation-rejected` with a key the vendor refuses), `set-assistants-none` (built-in only).
- **AI Assistants settings:** `set-ai-off`, `set-ai-pair`, `set-ai-waiting`, `set-ai-on`, `set-ai-connected`,
  `set-ai-disc`, `set-ai-log`.
- **Atlas Help (board 49):** `help-home`, `help-search`, `help-none`, `help-connect`, `help-assistant`, `help-keys`,
  `help-shown`: the Help window's content in the main window.
- **Assistants at work:** `ai-translate`, `ai-streaming`, `ai-review`, `ai-conflict`, `overview-ai`.
- **Suggestions and assistant setup:** the overview before and after connecting, `ov-first` and `ov-connected`; the
  Assistant popover, `asst-pop`; the setup sheet, `setup-1` to `setup-4` and `setup-done`; the Store Page with
  built-in suggestions only, `sp-builtin`, with Claude Code's, `sp-cc`, asking, `sp-ask`, receiving, `sp-streaming`,
  after accepting and dismissing, `sp-accepted`, Use and Edit, `sp-edit`, and German and Japanese, `sp-de` and
  `sp-ja`; App Information's General and App Review, `in-general` and `in-review` (`SuggestionsDebugScenes`).
- **API key and code answers:** the setup sheet with a key, `setup-key-1`, `setup-key-2`, `setup-key-bad`,
  `setup-key-3` and `setup-key-done`; the Store Page with a key, `sp-key`, and Generate Suggestions… open,
  `sp-key-ask`; the Assistant popover with a key, `asst-pop-key`; Age Rating's suggested answers, `in-age`, accepted,
  `in-age-done`, and with a key, `in-key`; Accessibility's for Apple Watch and iPhone, `in-ax` and `in-ax-iphone`
  (`AssistDebugScenes`).
- **Suggest Everything:** Overview's entry points, `ev-start`, and the Assistant popover's, `ev-pop`; the prompt
  copied and waiting, `ev-wait`, and while a page's Ask still sends, `ev-busy`; 9 of 18 on Overview, `ev-run`, on
  German's Store Page, `ev-run-store`, on Age Rating, `ev-run-info`, and the Assistant popover's Show Progress,
  `ev-run-pop`; nothing for 3 minutes, `ev-quiet`; the last one arriving, `ev-done`; stopped at 12, `ev-stopped`;
  with only a key, `ev-key`, and with nothing set up, `ev-none` (`EverythingDebugScenes`). `ev-wait` and `ev-busy`
  copy the prompt to the clipboard, as the real button does.
- **New languages:** languages Lumen's project has and its App Store page doesn't (Polish, Turkish, Hebrew), drafted
  by Claude Code: the banner on English (U.S.), `sp-newlang`; Polish's tab before it's added, `sp-newlang-tab`;
  Hebrew added with every draft accepted, `sp-newlang-added`; the languages sheet, `langs-sheet`; Review & Push with
  "Create the Polish page", `review-newlang`; Overview's New languages and Languages lines, `ov-newlang`; and
  Suggest Everything waiting, its scope listing the new pages, `ev-newlang` (`NewLanguagesDebugScenes`).
- **Review & Push:** `review`, `review-assistant`, `push-progress`, `push-partial`, `push-conflict`, `activity`, the
  `banner-*` scenes, and more (`ReviewPushDebugScenes`).
- **Analytics** (`AnalyticsDebugScenes`; "today" is Nov 11, 2026): setup, `an-off`, `an-waiting`, `an-norole`,
  `an-loading`; what's missing, `an-novendor`, `an-nosales`, `an-part-eng`, `an-part-sales`, `an-stale`; the funnel,
  `an-funnel`, `an-funnel-7`, `an-funnel-dl`, `an-quiet`, `an-nosub`, `an-new`; Break It Down, `an-bd`, `an-bd-de`,
  `an-bd-br`, `an-bd-lang`, `an-bd-src`, `an-bd-dev`, `an-bd-ppo`; What to Try, `an-find`, `an-find-wait`,
  `an-find-done`, `an-find-dis`, `an-find-none`; After Changes, `an-chg`, `an-chg-wait`, `an-chg-few`,
  `an-chg-price`; `an-sub`; settings, `an-set`, `an-set-vendor`; and the overview's card, `an-overview`.
- **Pricing** (`PricingDebugScenes`) and **Store Page** (`StorePageDebugScenes`): one scene per design screenshot.
- **App Information:** `info-*`, `a11y-*` and, for App Privacy, `priv-*` (`AppInformationDebugScenes`).
- **Screenshots:** the Preview page and Autopilot, `st-*` (`StudioDebugScenes`): `st-home`, `st-live-ar`,
  `st-noasst`, `st-design` (Connect a Design Project), one sheet per stage (`st-plan`, `st-wait`, `st-cap`, `st-fail`,
  `st-pick`, `st-des`, `st-choose`, `st-choose-rev`, `st-nodesign`, `st-loc`, `st-ready-sheet`), Design paused
  after Atlas closed while Claude Code designed (`st-des-paused`), Localize with captions out to Claude Code
  (`st-loc-captions`: Japanese and Arabic missing five each, German one too long), the strip on the
  page (`st-cap-page`, `st-pick-page`) and the new set (`st-ready`, `st-ready-de`, `st-ready-ar`, `st-ready-ipad`).
  On every device and with the project's new languages: `st-plan-all`, `st-cap-watch`, `st-cap-vision`,
  `st-pick-all`, `st-choose-all`, `st-loc-all`, `st-ready-sheet-all`, `st-live-watch`, `st-live-vision`,
  `st-ready-watch` and `st-ready-vision`. With no project report but a build with a watch app, `st-asc-watch`. A
  Claude Design link nobody has read yet, a long assistant name and a long screen name, `st-plan-link`. Problems: a
  refused command, `st-refused`; one cause on one screen in several languages, `st-group`; and iPhone Duo on a Mac
  without its simulator, `st-device` (a pretend Mac with iOS 26.5 and 27.0, `DebugSimulators`, so Install the iOS
  Simulator downloads nothing; the every-device scenes' Mac also runs Apple Vision Pro). iPhone Duo's simulator
  running but closed, so Atlas opens it and the run tries it again, `st-duo-closed`; Atlas not yet
  allowed in Accessibility, until a pretend person allows it, `st-duo-access`; a version 4 helper that can't open it,
  opened a moment later by a pretend person, `st-duo-opens`; stuck (SpringBoard crashed, a spinner), so Atlas
  restarts and opens it, `st-duo-stuck`; with a helper from before it could look at the Duo, `st-duo-old`; and the
  plan with it closed, with Open Now, `st-plan-duo`, and without Accessibility, `st-plan-duo-access`. A run nothing
  has arrived for in over an hour, with Continue, `st-stalled`.
  The Sets matrix, `sets*`, `viewer*` and `scope`; the Template editor, `tpl*` and `starter`; the template gallery,
  `gallery` and `gallery-elegant`, and a few of its templates rendered, `tpl-cinema`, `tpl-highlight-ar`,
  `tpl-market-de`, `tpl-poster-ja` and `tpl-swoosh-deco`; Captions, `cap*`
  (`ScreenshotsDebugScenes`). Captures, `capt*` (`capt-view`: one shown large), and assistants' proposals, `prop-*`
  (`ScreenshotsProposalsDebugScenes`). Pushing them, `shots-review`, `shots-push`, `shots-push-partial`, and
  restoring them from Activity, `shots-act` and `shots-act-restore` (`ScreenshotsPushDebugScenes`).
- **Claude Code started by Atlas:** through a pretend helper (`DebugUnixScriptRunner`), so nothing runs:
  setup's step 3 before and after the helper is saved, `cc-setup` and `cc-setup-installed`, and its test run
  connecting, `cc-setup-test`; Ask working, `cc-ask`; Suggest Everything working, `cc-everything`; Show Output,
  `cc-output`; not logged in, `cc-login`; refused steps, `cc-denied`; Settings, `cc-settings`; the Autopilot button
  with two runs, `cc-toolbar`; and Ask without the helper, `cc-hint` (`ClaudeCodeDebugScenes`). `cc-live` is the
  exception: setup's test through the helper really saved in the scripts folder, with your own Claude Code and login,
  and the MCP server on port 47399, away from the real app's. `CC_LIVE_FOLDER` picks the folder and
  `CC_LIVE_STOP_AFTER=<seconds>` stops the run.

The UI tests run through these scenes.

## Settings

The Settings window (⌘,, board 48) is a sidebar with search and nine panes (`Screens/Settings/`, `SettingsPane`,
`SettingsNavigation`, which Help's Show Me also sets):

- **General:** Appearance (Match System, Light, Dark: `AppAppearance`, applied at launch), the menu bar and Dock
  rows, how often Atlas checks App Store Connect, and the confirmations before pushing.
- **Accounts:** the saved keys, Remove… asked in place under the key (`AccountRemovalPanel`), Add Another Key…, and
  the vendor number for the key in use (disabled when its role can't read sales) with Reports by app, which opens
  Analytics.
- **AI Assistants:** where suggestions come from (`TranslationProvider`: your AI assistant, an API key, or built-in
  only). Each choice shows only its sections: with an assistant, the local server, paired assistants, Claude Code
  started by Atlas, "Assistants may suggest" (six switches, `MCPProposalKind`, replies to reviews and artwork
  included; choices saved before those two existed leave them on), "Assistants never" as locked rows, each app's
  Claude Design project, and Activity (Show Activity… is the log); with an API key, the provider, the key and the key
  assistant.
- **Suggestions:** the source language, the tone, the names never translated, the repeated-words keywords check
  (`AppPreferences.checksRepeatedWords`, which the Store Page's built-in suggestions follow), asking before Accept All,
  and what is never accepted for you.
- **Pricing:** the defaults for new apps and prices by country, and Apple's commission (Proceeds).
- **Screenshots:** whether Claude Code may open capture-only runs by itself (`AppPreferences.opensCaptureRuns`, off by
  default: each `request_recapture` waits for Accept), and the defaults an event's artwork Brief starts with (words in
  the art, moving versions).
- **Notifications:** whether macOS allows them, then what Atlas tells you about and how (`NotificationPreferences`,
  `AtlasNotifier`, `AtlasNotifications`): something needs you (Autopilot's turns, concepts ready behind a hidden
  sheet), App Review's status changes, a push that finished (a failed one always tells), new reviews (never, 3 stars
  or lower, every review; the first read of an app isn't news), Analytics' findings once a week, a sound, the menu bar
  icon's dot, and the Dock icon's count of what needs you (suggestions aren't counted).
- **Atlas Pro:** the plan and when it renews, Manage Subscription…, what Pro includes, Restore Purchases, Redeem a
  Code…; Free shows See Atlas Pro…, whose paywall opens on the Settings window (`ProGate.settingsPaywall`).
- **Privacy & Data:** what leaves this Mac, the activity (every push and every assistant call, Export… as JSON), the
  rendered images and ratings that can be made again (Clear…), the "Don't ask again" choices (Reset), and Remove All
  Keys and Data…, which deletes every key and paired assistant from the Keychain and Atlas's own files and settings,
  then quits (`LocalDataStore`; only its `supportItems` are removed, and DEBUG scenes and the tests' host delete
  nothing).

## Atlas Help

Help → Atlas Help (⌘?, board 49) opens the Help window (`Screens/Help/`): a sidebar with Search Help and every
article by group, a home page (searches to try, the Start here cards, Contact Support…), search results, and
articles with Back, where you are, Show Me (a Settings pane, a section of the selected app, or Review & Push, then
"Opened … in Atlas.") and related articles. The 18 articles are Markdown files bundled with the app
(`Managers/Help/Articles/help-*.md`): front matter (`id`, `group`, `title`, `summary`, `keywords`, `showMe`,
`related`), then blocks (`## ` heading, `1. ` steps, `- ` list, `> ` note, `| ` table), read by `HelpArticleParser`
and searched by `HelpLibrary` (every word must match; title, then keywords, summary, text). The Help menu also has
Keyboard Shortcuts, Connect App Store Connect, Fix a Problem, App Store Connect System Status, Contact Support… and
Send Feedback… (an email with Atlas's version, to the Info.plist's `ALSupportEmail` once it's set). View has Show
Sidebar (⌃⌘S).

## Translation providers

Settings → AI Assistants picks who suggests and translates: the assistant connected over MCP, an AI provider with an
API key, or Apple Translation on this Mac. The AI provider's key is kept in the Keychain and sent only to that provider
(`Managers/AIProvider/`). The pane checks the saved key when it opens, after a key is saved and when the vendor changes, with a `GET` for the
model translations use (no tokens spent), and says under the field whether it's saved and connected, rejected, or
couldn't be checked. Anthropic is called through the Messages API (`claude-opus-5-5`, low effort, with Anthropic's default fallback if a
request is declined); OpenAI through Chat Completions (`OpenAIChatAPI.model`); Google Gemini through
`generateContent` (`GeminiGenerateAPI.model`). Each field is asked for with its purpose
and limit, the tone, and glossary terms swapped for placeholders, so brand names are never sent for translation.

## Field suggestions

A suggestion is a proposed value for one field, in one Store Page language or one App Information page (General, Age
Rating, Accessibility per device, and App Review), with a reason. It never changes the field by itself: it shows under the field with Dismiss, Use and Edit
and Accept, and accepting queues an unpushed change tagged with who suggested it (`Managers/Suggestions/`,
`Screens/Suggestions/`).

- **Sources:** built-in checks that need nothing else (keywords that repeat the name or subtitle, empty URLs other
  languages fill, a copyright with last year, contact details the previous version had, no advertising when App
  Privacy's scan found none); the assistant connected over MCP (`suggest_fields`); an API key; and the AI provider.
- **An API key** (Anthropic, OpenAI or Google Gemini), set up from the same sheet or Settings → AI Assistants, lets
  Atlas ask the model itself, without an assistant (`Managers/KeyAssistant/`). Generate Suggestions… on a Store
  Page first lists what it will send and about how many tokens: the language's texts with their limits, and, when
  allowed, the commit messages since the last release tag and CHANGELOG.md's section from the project folder (git
  runs from Xcode's or the Command Line Tools' binary, else HEAD's reflog is read) and one page of the latest App Store
  reviews. Source code is never sent. The answer is checked like an edit and its suggestions are tagged with the
  key's API ("Anthropic API"). App Information's answers come from the code, so with only a key those pages say how
  many need an MCP assistant. While an assistant is connected, it suggests instead of the key. The key is kept in the
  Keychain apart from Settings → Translation's, which can use it too.
- **The bar** above each language or page counts them, filters by source, and offers Ask (copying the prompt, since
  Atlas can't start the assistant), Dismiss All, Accept All and Accept All in Every Language. Accept All asks
  nothing first; its toast, and Edit → Undo, put everything back. With Claude Code's helper saved, Ask starts Claude
  Code instead of copying (see [Starting Claude Code](#starting-claude-code-from-atlas)).
- **Suggest Everything** (Overview's assistant and Suggestions cards, and the Autopilot button) copies one prompt (or,
  with Claude Code's helper saved, starts Claude Code with it) for every field the connected assistant can suggest, listing what it covers page by page: the Store Page's fields
  that can change, General, Age Rating, Accessibility and App Review. While the version is in review only what can
  still change is asked, and App Review says it's locked. The assistant announces its plan with
  `begin_suggestions`, and Overview then shows a card with the run's total, each page's progress and Review, and
  Stop Receiving; pages, languages and devices say what's still coming, with striped placeholders where a
  suggestion will land, and a bar on each page leads back to Overview. When the run ends a toast gives the total;
  Accept All (n) takes what's left from the run and its toast offers Undo. A run that sends nothing for two minutes
  says the assistant stopped sending. With only an API key it generates on the Store Page, and with nothing set up,
  setup opens and says why (`Managers/Suggestions/Run/`, `Screens/Overview/Components/SuggestEverything/`).
- **Where they show:** the language picker and App Information's page column count them, and Overview's Suggestions
  card sums them by area and source. Built-in ones are counted once their page has loaded.
- **New languages:** once the assistant reported the project (`report_app_support`), each language its string
  catalogs have and the App Store page doesn't is a built-in suggestion to create its page: a banner on the App
  Store languages (Review… opens "Languages in the app, not on the App Store", Add All n adds them, with Undo), and
  its own entry in the language picker, marked New, with the fields empty and their suggestions. Not Now stops
  suggesting it; Create Page, or accepting or editing one of its fields, adds it. An added language says its page is
  created when you push, with Don’t Add. Review & Push shows "Create the Polish page" under "Store Page · Polish
  (new)", with its fields under it, checked and discarded together; the page is created even before it has text.
  When App Store Connect has the language by the time it's pushed (added there, or created along with the other
  level), the texts go onto that localization if they overwrite nothing (`ExistingLocalizationUpdate`); otherwise,
  and whenever the Store Page or an assistant reads it again, the queued page becomes edits of what's there.
  Overview's Suggestions card names them under New languages (their drafts aren't counted under Store Page), and the
  Store page card says "10 · 3 more in the app" or "10 · 2 new to push". Suggest Everything asks for them too.
- Suggestions and decisions are kept on this Mac (`FileFieldSuggestionPersistence`), and DEBUG scenes keep them in
  memory.

## Analytics

Analytics answers three questions for one app: where people drop off, where it's worse than it should be, and what to
change next. It's a tool for deciding what to edit: every number leads to an action or is left out. The design is on
the canvas's Analytics page (boards 29–37).

- **Where the numbers come from:**
  - **Apple's analytics reports** (the Analytics Reports API): impressions, product page views, first-time downloads
    and redownloads by day, territory, source and device (the Standard "App Store Discovery and Engagement" and "App
    Store Downloads" reports), and by product page (the Detailed ones). Apple has to be asked once per app
    (`POST /v1/analyticsReportRequests`, an ongoing request plus a one-time snapshot of earlier data), and only an
    Admin key may ask. The first reports take 1 to 2 days. That request and stopping it are the only writes
    Analytics makes, and only after "Ask Apple for Reports" or "Stop Asking Apple for Reports".
  - **Sales and Trends** (`GET /v1/salesReports`, daily, version 1_3): trial starts, conversions, renewals,
    cancellations with Apple's reasons, charges, refunds, proceeds and active subscriptions (the Subscription Event,
    Subscriber and Subscription reports). It needs the team's vendor number (Analytics settings) and a key that can
    read sales. Apple's analytics reports have subscription reports too, but they leave out rows with fewer than five
    people, which hides most of a small app's subscriptions; Sales and Trends is exact.
  - Everything is kept as JSON in `Application Support/Atlas/Analytics` (`AnalyticsStore`) and worked out on
    this Mac. Apple reprocesses days: a later file replaces a day's numbers, never adds to them
    (`EngagementArchive`). Reports are downloaded once a day while Atlas is open, or only when Analytics is
    opened (a setting); a toast says when an app's first reports arrive.
- **How sure, everywhere the same way** (`AnalyticsStatistics`): a rate has a 90% range (Wilson interval) and a
  three-bar meter (three bars within ±12% of the rate, two within ±30%). "Better" or "worse" than the app's average
  only when the whole range is above or below it. Under 30 in the step before or 3 in the step itself is "too few to
  tell": the counts are shown, "1 of 40", with no percentage. Two periods are compared with a two-proportion test
  ("sure" beyond 99%, "fairly sure" beyond 90%) and need at least 100 and 5 on both sides. Only "worse" has a color.
- **What's missing is said where it's missing** (`FunnelGap`): a step without a number says why on the step (needs
  the vendor number, the key can't read sales, waiting for Apple) and offers the fix. A key that isn't Admin, and data
  older than Apple's usual 1 to 2 days, are states of their own, not errors.
- **The views** (`Screens/Analytics/`): Funnel (the strip, the biggest loss in words, the timeline with what was
  pushed from Atlas marked on it), Break It Down (a ranked, sortable table; the selected row's inspector says
  which page the territory sees, whether it's machine-translated, and its price against purchasing power), What to Try,
  After Changes and Subscriptions. The period applies to all of them.
- **Findings** (`FindingRules`, after each download, on the last 28 days): a step that fell against the 28 days
  before; territories that download surely less than the app's average, with what their page looks like; territories
  whose trials convert less where the price is well above purchasing power; many cancellations before the first
  renewal with no retention message live. An assistant adds its own with `add_finding`. A finding's button opens its
  section with a "From Analytics" bar and Back to Analytics; one whose section got a push afterwards moves to Acted On
  with that change's result; a dismissed one comes back only if its number moves by more than a quarter. New findings
  show as a gray count on the section picker (purple stays for suggestions to accept).
- **After Changes** (`ChangeLog`, `ChangeResult`): each push is read from the push history as a change measured on
  the step it should move (name, subtitle or keywords: tap-through from search; description: downloads per page view;
  screenshots: page views per impression; paywall text: trials per download), 28 days before against 28 days after,
  in the territories that see the changed languages. Price changes link to Pricing → Results.
- **Not there, because Apple's reports don't have it:** a product page optimization test's treatments and Apple's
  result for them, and sales by source or product page.

## Navigation

The sections left the toolbar for the sidebar (the design canvas's Navigation page, boards 41–43), so the window has
room for more of them; the toolbar names the section and holds its actions.

- **The sidebar** (`Screens/Main/Sidebar/`): the app menu, then the sections in three groups (`AppWorkspaceSection`,
  `AppWorkspaceSectionGroup`): Overview; Store Listing (Store Page, Screenshots, In-App Events, App Information,
  Pricing); After Release (Reviews, Analytics). ⌘1–⌘8 follow that order. Each row shows what's waiting there
  (`SectionBadgeCounts`): suggestions in purple, Analytics' new findings in gray.
- **The app menu** (`AppSwitcher`, `AppSwitcherMenu`): the selected app and its team; a click lists every app of the
  key with its own count, a search field once there are more than eight, the sort order, and Switch Account or Key….
- **The version's status** (`VersionStatusFooter`, `VersionStatusSummary`) stays at the bottom of the sidebar in
  every section: "Version 1.4 · Not submitted yet" with Submit…, "Rolling out · day 3 of 7", "Rejected by App
  Review" with Fix…. A click opens the Submit sheet before submitting and Overview's version card after.
- **The toolbar** (board 57, README-Toolbar; `Screens/Main/Workspace/Toolbar/`) leads with the section's title over
  one line of its state (`WorkspaceToolbarTitle`, `WorkspaceSectionStatus`): "32 suggestions · 3 not pushed", with the
  not-pushed part a link that opens Review & Push on that section only (`ReviewScope.section`, `focus(on:)`; its push
  reads "Push 3 from Store Page…"). Overview leads with the app and its version. The pages lost their own title row:
  `SectionHeader` is the one-sentence description and the page's controls. With the sidebar hidden the section menu
  comes first. At 940 points of detail width the Autopilot and Review & Push labels fold to their icons; under 620
  the title goes (`WorkspaceToolbarLayout`).
- **Autopilot** (`Toolbar/Autopilot/`): one split button in every section, replacing the Assistant button. Its label
  is what Autopilot makes there (`WorkspaceAutopilotAction.actions(for:)`): Suggest Everything…, Suggest Texts…, Make
  Screenshots…, Suggest Pages…, Make Event Artwork…, Suggest Answers…, Suggest Prices…, Draft Replies…, Find What to
  Try…; the arrow lists the section's other actions, Everything for the app, the assistant's connection (its status
  popover, the old Assistant popover) and Settings…. Actions a section already had run that section's flow through
  `WorkspaceIntent.autopilot` (the guided run, page shots, event artwork) or an existing intent; the new ones ask
  Claude Code from the toolbar (`WorkspaceAutopilotAsk`, `AssistantAskStarter`; copied when it can't start). Running,
  it shows a ring and what's being done; when the guided run waits for the person (`AutopilotTurn`), purple with
  "Choose the Look" and a click opens that step (`WorkspaceAutopilotState`). Free shows PRO on Pro's actions and opens
  the paywall. ⌥⌘A runs it and ⇧⌘P opens Review & Push, both in the Product menu.
- **One Review & Push.** No page has a push button: Overview's cards, Screenshots' strip and set card, Pricing's
  starting price and new subscriptions, and Analytics' findings say what's waiting "in Review & Push, top right"; the
  toolbar button reads Up to Date when nothing is. A product page's button is Submit for Review…, which still opens
  Review & Push on the page first.
- **Sections open loaded** (`Screens/Main/Workspace/SectionModels/`): the window keeps each section's model for the
  four apps opened last (`WorkspaceSectionModels`, `AppSectionModels`), stamped when a read finished and read again
  after Refresh, a push or 15 minutes. Two seconds after an app opens, and again after Refresh or a push, the
  sections the person isn't looking at are read in the background, one at a time in the sidebar's order
  (`SectionPrefetcher`, `WorkspaceSectionWarmer`, `SectionPrefetchModifier`), each model made the way its section
  view makes it; Screenshots reads its sets too, Analytics only its context (Apple's reports still download when it
  opens or each morning). A section opened while its read runs waits for it instead of reading again. Reading
  ahead stops when the app changes and while App Store Connect's hourly quota is in its last quarter
  (`AppStoreConnectQuota`, from every read's `X-Rate-Limit` header). DEBUG scenes read ahead only when asked.

## Ratings & Reviews

The design is on the canvas's "Avaliações, envio e eventos" page (board 38).

- **Reading** (`LiveReviewsServices`): `GET /v1/apps/{id}/customerReviews` with `include=response`, newest first, 200
  at a time (Show More reads the next page); the two newest released versions' reviews are matched by
  `/v1/appStoreVersions/{id}/customerReviews` so a review says which version it's about. Apple's API only has written
  reviews, so the ratings card's average and count come from the App Store's public lookup, per storefront that has
  reviews (up to 40) plus the U.S. (`StoreRatingLookup`); the bars are the written reviews of the last 90 days.
- **Kept on this Mac** (`ReviewsStore`, `Application Support/Atlas/Reviews/`): the reviews read, the suggested
  replies, the groups, what was dismissed and the translations. A read older than 15 minutes is refreshed.
- **Languages** are detected on this Mac (`ReviewLanguage`, NaturalLanguage) and reviews are translated by Apple
  Translation (`AppleReviewTranslator`), once, and kept. The switch shows everything as written; Show Original
  switches one review. A language that isn't downloaded yet offers the download.
- **Replies** (`ReviewsViewModel+Replies`): a reply is public once Apple publishes it, so nothing is sent without Send
  Reply (`POST /v1/customerReviewResponses`, which also replaces an earlier reply). The toast's Undo deletes the new
  reply or puts the earlier one back. A suggested reply shows what it means in English; Edit… changes it first.
- **What people write about** (`ReviewTheme`): groups an assistant sent, each with one action: Reply to All (one
  message per language, sent under each review of the group that has no reply; `ReviewBulkPlan`), Open Pricing for a
  country, Suggest for Store Page, or Show Reviews.
- **Since the newest version** (`VersionRatingComparison`): the written reviews' average for the current version
  against the ones before, said only as sure as the numbers allow (at least 10 on each side; fairly sure at 90%, sure
  at 99%).
- **Reply Automatically** (board 58, `AutoReplyCenter`, Pro): on each hourly check Claude Code (purpose `.autoReply`,
  only in a project folder Atlas already knows) writes a reply to each review newer than the moment it was turned on
  and at most a week old; without Claude Code the person's API key writes them, only when Settings → AI Assistants
  lets it read reviews (`AutoReplyKeyPrompt`). Replies come back through `propose_review_replies` with `waitTopics`
  and `unsure`, and `AutoReplyDecision` decides: draft and tell, or send by itself after the wait (15 min, 1 h, 3 h)
  when the rating, language, topics and App Review's rules for replies allow; everything else waits, with the reason
  and a notification (Send Reply / Open Reviews buttons). Due replies go out on the 30 s background tick through the
  same write as Send Reply, at most the daily cap, and **never before a reply the person sent by hand reached the App
  Store** (`ReviewsSettings.sentReplyByHandAt`). Pause in the strip, the Autopilot menu or the menu bar; History's
  Undo deletes the reply and keeps the draft. Kept as `auto-reply-<appID>.json` next to the reviews.
- **Free and Pro:** Free reads, translates and replies by hand; suggested replies, groups, Reply to All and Reply
  Automatically are Pro.
- **Not there, because Apple's API doesn't have it:** resetting the rating summary with a new version (the row
  explains it and links to App Store Connect) and ratings without text.

## Submit for Review and release

The design is on the same page (board 39). Everything here writes to App Store Connect directly when the person
presses the button; it isn't queued in Review & Push, though the sheet can push what is waiting there first.

- **Which version** (`LiveReleaseServices.followed`): the one with App Review or rolling out, else the one being
  prepared, else the live one, for the platform Store Page shows.
- **The version card** (`VersionCard`, first on Overview): before submitting, what goes to Apple and what's missing
  (the build, What's New per language, changes not pushed yet, App Review information, the events that go along);
  after, the steps (Submitted, Waiting for Review, In Review, Approved, On the App Store) with the day this Mac
  saw each one happen (`ReleaseStore`; a version found already live has no dates), and the action that fits: Cancel Submission, Release Now, Pause or Resume Phased
  Release, Release to Everyone Now, Submit Again. The ones that can't be taken back ask first.
- **The Submit sheet** (`SubmitForReviewSheet`, `ReleaseViewModel+Submit`): the build (only processed, unexpired
  ones can be chosen); What's New in every language, with a suggestion accepted in place; "Push N changes with this
  submission"; the In-App Events that are complete; one encryption question (kept in App Information → Export
  Compliance and written on the build); release after approval, by hand or on a date; and the 7-day phased release.
  The footer says exactly what's missing ("To submit, add What's New in Italian and answer the encryption question").
- **What a submission sends** (`SubmissionPlan`): the build relationship and `usesNonExemptEncryption` when they
  change, `releaseType` and `earliestReleaseDate`, the phased release (created or deleted), then one
  `reviewSubmissions` with the version and the events as items, marked `submitted`. Canceling and submitting again
  update the same submission; releasing posts an `appStoreVersionReleaseRequests`.
- **Following it:** the status is read when an app is selected and every 15 minutes for versions on their way; a
  move (in review, approved, rejected, released) is said in a toast and a notification (`ReleaseNotifier`).
- **Not there, because Apple's API doesn't have it:** App Review's message for a rejected version. The card says so
  and links to App Store Connect; the fix (the demo account, the notes) is made in App Information.

## In-App Events

The design is on the same page (board 40). In-App Events is its own section (⌘4), not a Store Page tab.

- **Reading** (`LiveInAppEventsServices`): `GET /v1/apps/{id}/appEvents` with its localizations, and the card and
  details images of each event's primary language. Events that can still change come first, ended ones last.
- **Texts** (`InAppEventField`): Event Name 30 characters, Short Description 50, Long Description 120, per language.
  The language bar lists the event's languages, the store page's and the suggested ones; a language that isn't
  written shows what people there see instead (the primary language).
- **Suggestions** (`InAppEventsStore`): an assistant sends all three texts for a language with one sentence on why
  they read this way (`propose_event_texts`). Accept writes them, Accept All Languages every one, and the toast's
  Undo puts the suggestions back.
- **Everything goes through Review & Push** (`InAppEventChangeBuilder`): a field of a written language is a `PATCH`
  of its localization, a new language one `POST` with everything written for it, and a new or duplicated event a
  `POST /v1/appEvents` followed by its languages (which refer to it as `{createdID}`).
- **To App Review:** an event that's complete (every language written, both images, dates) goes with the version
  from the Submit sheet, or on its own with Submit Event….
- **Images and video** (board 47): a strip under the event's title shows the card and details image, or what's
  missing, and what a run is doing. **Choose Files…** (free) takes the person's own images or loops, by their shape.
  **Make the Artwork…** (Pro, `PaywallContext.eventArtwork`) opens a four-step sheet, `EventArtworkSheet`:
  - **Brief:** what the art should show (written by Atlas from the event's texts, editable), a capture from
    Screenshots as reference, words in the art (the name drawn per language), a moving version, and the look: a new
    look in the app's brand (with a design project), Atlas's event layouts (`EventArtworkTemplate`, by badge), or
    extending the card the event has (only the details image is new). The footer says how long it takes.
  - **Making:** Atlas starts Claude Code (`ClaudeCodeRunPurpose.eventArtworkConcepts`) or copies the prompt when it
    can't. Three concepts arrive one by one, each a matching pair. **Hide · Keeps Going** closes the sheet; the strip
    and the menu bar icon show the progress, and the icon gets its dot when the concepts are ready. Stop adds nothing.
  - **Choose** one (Claude Design marks its pick), then **Check** it under the App Store's text in the languages
    worth a look (the primary, the longest name, CJK, right-to-left), with four checks (`EventArtworkConceptChecks`).
    **Ask for Changes…** redraws only that pair.
  - **Use This Artwork** queues the pair, accepted, for the primary language in Review & Push
    (`EventArtworkFlow.use`), with the moving version where there is one, and for each other language that needs
    its own: art drawn for that language, or one with its own image in App Store Connect to replace. The others
    show the primary language's (Apple's fallback), so no copy is uploaded (`InAppEventArtworkCopies`); a
    language the push creates gets none by itself either. The toast's Undo takes it back.
  - Runs are kept on this Mac (`EventArtworkStudio`, `EventArtworkRuns/runs.json`); one left drawing when Atlas quit
    moves on at the next launch with what arrived.
- **Not there yet:** reading how an ended event did from Apple's analytics reports: the card links to App Analytics.

## AI assistants (MCP)

Settings → AI Assistants turns on a Streamable HTTP MCP server at `http://127.0.0.1:47321/mcp`. It's off by default,
only accepts connections from this Mac, and runs only while the app is open (`Managers/MCP/`). "Set Up Your AI
Assistant" (from the Autopilot button's menu, the overview or a suggestion bar) walks through choosing a client,
turning the server on with Suggest only or Suggest and edit drafts, adding Atlas to the client, and a first
call.

- **Pairing:** each assistant gets its own bearer token from the "Pair an assistant" sheet, stored in the Keychain.
  Revoking it in Settings ends its sessions. Claude Code's command registers Atlas once for every project
  (`--scope user`), removing an older entry first: one server serves every app.
- **Connection per app:** the overview's card and the Assistant popover compare the folder each open session works
  in (its MCP roots) with the app's project folder (the one Atlas starts Claude Code in), so they say "connected"
  only for this app's folder, "connected to another project" (naming that app), "is ready" when Atlas starts it, or
  ask for the app's folder with Choose Folder…. A request whose token matches no pairing (an old registration) makes
  them say "Claude Code can't connect" with Reconnect… until an assistant gets in with a paired token; an ended
  run's late request doesn't count. Scenes `ov-refused`, `ov-elsewhere`, `ov-unattached`, `asst-pop-refused`.
- **Tools:**
  - Store text: `list_apps`, `get_listing`, `list_missing_translations` and `propose_listing_text`.
  - App Review's metadata rules (`StoreTextGuidelineCheck`, `Screens/StorePage/Model/Validation/Guidelines/`):
    store text and captions are checked for what App Review rejects from the words alone: pricing such as “free”
    in any language, prices, discounts and trials (2.3.7; SimProps 1.0 was rejected for it), other platforms and
    stores (2.3.10), other apps' names in the name, subtitle and keywords (2.3.7, 4.1(c)), unverifiable claims in the
    name and subtitle (2.3.7), beta and demo (2.2), placeholders (2.1(a)), “coming soon” (2.3) and “For Kids” (2.3.8,
    5.1.4(b)). `propose_listing_text`, `suggest_fields` (code `guideline`) and `propose_captions` refuse such text
    with `issues` [{kind, guideline, phrases}] and how to rewrite it; App Store Connect's own text can always come
    back. `get_listing` and `get_store_page` carry `storeTextRules` (also the ones only judgment can apply, such as
    2.3.1, 2.3.9 and 2.3.12) and say in a locale's `states` which fields already break one. The server instructions,
    the prompts and Generate Suggestions… carry the rules too, and Generate Suggestions… drops what breaks one. The
    person is only warned: under the field in the Store Page and on the change in Review & Push.
    In-App Texts (in-app purchase, subscription and group names and descriptions) follow their own set
    (`StoreTextGuidelineKind.applies(to: InAppTextField)`): pricing, other platforms, placeholders, “coming soon”
    and “For Kids”, without claims, other apps or betas (“Best Value” and “Early Access” are ordinary product
    names). An in-app purchase may name a trial length: Guideline 3.1.1 asks a non-subscription app's free trial
    to be a non-consumable at Price Tier 0 named “XX-day Trial” (SimProps's “7-day Trial”); a subscription's trial
    is an introductory offer, so its texts may not. `propose_in_app_texts` and `propose_subscription` refuse what
    breaks one, `get_in_app_texts` carries `textRules` and per-locale `states`, the In-App Texts cell and editor,
    Create Subscription and Review & Push warn the person.
  - Review Notes: `get_in_app_review_notes` reads each subscription's and in-app purchase's Review Information ›
    Review Notes (`reviewNote` on `inAppPurchases` v2 / `subscriptions`, one per product, 4,000 characters), its
    state and `writesTo` (current, next review submission when approved, locked while with App Review);
    `propose_in_app_review_note` queues a `PATCH /v2/inAppPurchases/{id}` or `/v1/subscriptions/{id}` of
    `reviewNote` (`InAppReviewNoteChangeBuilder`, ids `storePage.<appID>.inAppReviewNote.<productID>`) under
    "Review Notes · <name>" with the reason, or refuses it (over_limit, empty, unknown_product,
    changed_by_person, locked). The store text rules don't apply to them.
    In-App Event texts, retention messages and review replies follow their own page of Apple's rules
    (`StoreTextGuidelinePlace`): events (Apple's In-App Events page, 2.3.13) no specific prices or discounts
    (“free” is allowed: a free weekend is an event), no claims such as “#1” or “the best app”, no all capitals or
    repeated punctuation (`emphasis`, checked only here), no other platforms, placeholders or “For Kids”;
    retention messages (App Store Connect's retention message guidelines) no offers, discounts or prices, also
    “one month free” and trials, no unverifiable claims or statistics (“92% of parents”), no emphasis, while a
    factual loss and upcoming content are fine; replies (5.6.1) no marketing (prices, discounts, promo codes) and
    no unfilled “[name]”, while “feel free” and a free trial in a support answer are fine. `propose_event_texts`
    and `propose_review_replies` skip what breaks one (`issues`), `propose_in_app_event` and
    `propose_retention_message` (also its shorter suggestions) refuse it; `get_in_app_events`, `get_retention` and
    `get_reviews` carry `textRules`. The event field, the retention editor, the reply editor and Review & Push
    (event texts, new events, retention messages) warn the person. The caption editor warns about the caption
    being written, and the header and search artwork checks count “free” and trial lengths as a price.
  - Versions: `get_app_versions` lists each platform's versions, whether a new one can be created (one in
    progress per platform) and the number Atlas suggests, and each version's builds (number, processing state,
    upload date) with the one attached, read as the Submit sheet reads them; `propose_app_version` queues "Create version 1.5" in
    Review & Push (`POST /v1/appStoreVersions`), the same change as the Store Page's New Version…. A push after one
    that created it finds the version by number and platform instead of failing.
  - A queued version counts as the one being prepared: `get_listing`, `get_store_page`, `get_app_information`,
    `propose_listing_text` and `suggest_fields` take its number as `version` and read it from the version before it,
    editable. What's written for it (version fields, copyright, release, App Review details, and name, subtitle,
    privacy URLs, categories and age rating, which App Store Connect only takes in the app info it makes with a new
    version) waits tied to it
    (`PendingChange.dependsOn`, `QueuedAppVersion.tie`) as fields of its "Create version 1.5" row, with placeholders
    for its ID, localizations and App Review details (`QueuedVersionPlaceholder`). The push sends them after it and
    fills the placeholders once it's created (`QueuedVersionPushState`: localizations copied from the version before,
    App Review details made by the first field when it has none; the app info in an editable state, else the live one,
    with its localizations and age rating declaration); when it isn't created they're not sent and stay
    queued. Discarding the version, or queuing another number for its platform, discards them. A number that's
    neither in App Store Connect nor queued is refused with "propose it with propose_app_version first".
  - Field suggestions: `get_store_page` and `get_app_information` read the fields, their limits and the suggestions
    already open; `suggest_fields` sends suggestions per item (queued, unchanged, replaced, or refused with a code:
    `over_limit`, `unknown_field`, `unknown_locale`, `locked`, `not_permitted`, `invalid_value`, `guideline`). With Suggest and
    edit drafts, `"apply": true` queues the values as changes instead. Store Page items need the store text
    permission, App Information items the app information one. `total` drives the bar's progress while the
    assistant sends them. Both read tools (and `get_listing`) list `languagesNotOnAppStore`, the languages the
    project has and the App Store page doesn't (suggested, added, or said Not Now to), and `get_store_page` lists
    the suggested ones in `locales` with `new: true`. `suggest_fields` takes them as locales: they stay suggestions
    in their own tab, even with `apply`, until the person adds the page.
  - Suggest Everything: `begin_suggestions` takes the plan, one entry per field, and returns the run's id, how
    many Atlas counts, and what it skipped with a code (`changed_by_you`, `locked`, `in_another_request`,
    `already_suggested`, and the `suggest_fields` ones). `suggest_fields` calls carry the run's id, and are refused
    with `run_stopped` once the person stops receiving; `end_suggestions` ends the run.
  - Prices: `get_prices`, `get_price_points` and `propose_prices`. Proceeds use the commission from Settings →
    Pricing. Every price proposal is refused for apps set to Keep my prices, and a price that isn't a price point is
    refused with the two nearest ones.
  - App Information: `get_privacy_questionnaire` and `propose_privacy_answers` fill the App Privacy worksheet as
    unreviewed suggestions (App Store Connect has no API for App Privacy); `get_age_rating` and `propose_age_rating`
    queue answers that wait until the person ticks Confirmed; `get_compliance` and `propose_compliance_answers`
    suggest App Compliance answers (trader status and details, ICP Filing Number or stop selling in China mainland,
    regulated medical device), kept on this Mac on each regulation's card until the person accepts or dismisses
    them. Accept All never takes them, and Apple's API takes none of them except stopping sales in a country.
  - Screenshots: `get_screenshot_context`, `list_captures`, `get_capture`, `get_template`, `get_captions`,
    `measure_caption` (the same fit engine the renders use), `render_preview`, `propose_template`,
    `propose_captions` and `list_proposals`. `get_capture` and `render_preview` return PNG images. Slots are
    numbered from 1. Screenshot proposals wait in their own Proposals sheet, opened from the toolbar's assistant
    indicator, rather than in Review & Push.
  - **Redoing some captures** (`Managers/Autopilot/Recapture/`, `Managers/MCP/Tools/Autopilot/Recapture/`): a
    capture-only run isn't a new run. The app's finished run is opened again in place with `run.recapture`
    (`AutopilotRecapture`: the plan's targets and App Preview moments redone, why, and what Cancel gives back), so the
    plan, look, template and captions stay. `totalCaptures`, `remainingTargets`, `isSettled` and `next_step` count
    only those targets, `report_capture` refuses the others, and captures from before it opened don't count
    (`isRedone`). Pick (`AutopilotRecapturePickView`) shows each redone capture beside the one before; then
    `placeRecaptures` puts the final ones in their slots (`AutopilotLocalizer.placed`), makes the App Preview again
    when moments were recorded again (the artwork stays, `extrasPlan(for:)`), and the run is back in Review & Push,
    where render keys send only the changed images. Cancel Run puts the captures, Review and end back. Opened from
    Screenshots → Captures (⌘-click, a row or a column: `CapturesViewModel+Selection`, then Capture Again with
    Claude Code; Replace… swaps one PNG with no run, checked by `CaptureReplacement`), or by `request_recapture`
    (screens or slots, locale, device, Duo pose, moments, reason, evidence): queued as an
    `AutopilotRecaptureRequest` in `AutopilotPlanProposals.recaptures` (status `queued` with `requestId`, shown as
    `RecaptureRequestBanner` with Accept and Decline), or opened at once (`opened`) with Settings → Screenshots on.
    `request_page_recapture` does the same for a product page (at most 3 screens, `PageRecaptureTarget`): accepted, it
    turns on the page's Capture Screens Again (`PageShotsStudio.openRecapture`, making the page's run at Plan when it
    has none). `mark_captures_stale` sets `ScreenshotCapture.stale` (`CaptureStaleness`), labelled Out of date in the
    grid and viewer and returned by `list_captures` with `capturedAt`. DEBUG scenes `ap-recapture-request`,
    `ap-recapture-run`, `ap-recapture-pick`, `ap-captures-stale`, `ap-recapture-no-run`, `ap-recapture-make-duo`. With no saved run (none, or a
    new plan never started) the run is made from the set's captures (`AutopilotRecapturePlanFromCaptures`: a screen a
    slot named by the set or its capture files, the devices, languages and sizes of the captures, iPhone Duo's pose
    slot by slot in `AutopilotRunChoice.duoSlotPoses`, the open plan's steps and the queued `update_capture_plan`
    setup), kept in the request (`fromCaptures`) until Accept; only targets with a capture can be asked for ("… has no
    captures in ja on ipad"), App Preview moments come back in `unknownMoments`, and Cancel takes the run away again
    (`madeFromCaptures`). In a capture-only run `get_capture_plan` lists only its languages and devices, and each
    capture's `previousPixelSize`.
  - Screenshot Autopilot: `get_capture_plan` returns the plan, the simulator commands and an upload URL;
    `update_capture_plan` writes the screens and steps; captures are sent as raw PNG bodies to
    `POST /autopilot/<token>` on the MCP server (the app is sandboxed, so it can't read the assistant's files), which
    returns an upload id for `report_capture`; `report_capture_problem` reports a screen that can't be reached.
    On iPhone Duo each UI test run goes between `start_display_recording` (it opens the Duo, then records its inner
    display) and `finish_display_recording` with the test's `-resultBundlePath`, which gives back each screenshot the
    test attached as the inner display at that moment: an upload id for `report_capture`, a small preview, how long
    before the test's screenshot it was taken, and a check when the frame is black (the Duo closed) or not settled.
    Each locale carries `launchArguments` for the simulator and `testArguments` (`-testLanguage de -testRegion DE`)
    for UI tests, so `xcodebuild test` needs nothing in front of it. A command the session wasn't allowed to run comes
    as `refusedCommand`: its fix is a change to the project, so retrying doesn't add it to the plan's commands.
    So does a fix the assistant marks `changesProject: true`, or one that doesn't read as a command
    (`AutopilotProblem.needsProjectChange`). The plan carries `preflight` checks (`AutopilotPreflight`: identifiers
    rather than visible titles, sample data in each language, no forced `-AppleLanguages`, no `VAR=value`, derived
    data and exports in the project folder, since Atlas's Claude Code reads only there, not in `/tmp`) and a
    `rehearsal` language (another script than the primary's, else German): `next_step` gives each screen on each
    device in those two first (`phase: rehearsal`), then its other languages, so a screen or device that can't go on
    holds back only its own languages, never the rest of the run. An open problem holds the same screen on the same
    device in the other languages, so one cause is reported once; problems with one cause share a card
    (`AutopilotProblemGroup`), and reusing the primary capture for a change to the project covers the screen's other
    languages (`primaryCaptureTargets`). A device this Mac can't run is reported once with `affectsDevice: true`: it
    holds every screen on that device, the other devices keep going, and its card installs the simulator or leaves
    the device out (`AutopilotCenter.leaveOut`, never iPhone); the assistant never downloads a runtime itself. A
    problem reported on a screen already captured (out of date) and retried is captured again, and the new capture
    replaces the old ones.
    `next_step` says what to do next (capture, wait, design, revise, write captions, done). `get_design_brief`,
    `report_design_source`, `propose_direction` and `revise_direction` carry the design stage. The brief carries the
    design project's summary once it was read, and says to design from the brief rather than stop when the project
    can't be opened: the Claude Code Atlas starts only has Atlas's tools, so it can't open Claude
    Design or Figma, and its system prompt says so too. Reading the brief is noted in the run (`briefReadAt`) and its
    log, and so is reading the design project while it designs. And
    `propose_captions` with the run's id shortens captions while localizing. The person plans, picks, chooses and
    pushes in the app; the assistant never pushes. The plan lists each device's screens and how to capture them
    (`devices`), and marks the languages not on the App Store yet (`notOnAppStoreYet`); `update_capture_plan` takes
    `device: watch` or `vision` for those devices' own screens, and `sameMomentAs` for a Vision Pro window. When the
    plan says `chooseScreens`, the assistant picks the screens and sends them with `replace: true`, which puts them
    in place of the plan's on each device it sends, before the first capture.
  - The app's devices and languages: `report_app_support` records the targets and platforms, and the languages in
    the string catalogs with how much of each is translated. Autopilot plans from it, and Store Page suggests pages
    for the languages the App Store doesn't have yet.
  - Every proposal is validated like a manual edit (limits, URLs, read-only versions), then queued as a change tagged
    with the assistant's name.
  - When a person already changed the same field, both versions are kept and Review & Push asks which to push.
  - Settings decides what assistants may propose, and the log says why a call was refused.
  - **Reviews:** `get_reviews` reads the written reviews (refreshing them when they're old), with each review's
    language, version, reply and suggested reply. `propose_review_replies` leaves a reply under each review for the
    person to send, edit or dismiss, and `propose_review_themes` sets "What people write about", with one message per
    language for Reply to All. Neither sends anything, and both need Pro (`ProAssistantGate`).
  - **In-App Events:** `get_in_app_events` reads the events, their texts per language and the languages still
    missing; `propose_event_texts` suggests all three texts for a language, refused over a limit with the count.
    `get_in_app_events` answers what was chosen and what App Store Connect has without notes of the assistant's
    own: the open suggestions (`stale` once App Store Connect has that language written; `withdraw_event_texts`
    takes back the caller's own), the queued texts and art (each file's original name, SHA-256 and origin, kept in
    `.atlas-info.json` beside it; `queuedArtworkSummary` by file; `sameAsPrimary` and `identicalCopies` for copies
    of the primary language's art), `mediaDetails` (App Store Connect's file name, size, poster frame and
    processing, and the file on this Mac it came from), and the push's progress (`pushInProgress`, `pushStatus`).
    `propose_event_artwork` goes into the primary language unless told otherwise and leaves out a copy of the
    primary's file for a language that shows it anyway. The art is designed like Autopilot's Claude Design pages: `get_in_app_events`' `design` carries the app's look,
    what Atlas knows of it, its design project (design there when it opens, else from its summary) and how to make
    each piece. `render_event_artwork` renders a page as a 4K still or, with `motion: true`, its CSS and SVG
    animation as a 20-second seamless loop at 30 fps and 1920 × 1080 (or 1080 × 1920) in a .mov, through the same
    `ArtworkWebLoop` as Autopilot's header loops; `propose_event_artwork` queues it for the person to accept. The
    event's "Ask Claude Code…" starts a run with that prompt (`InAppEventArtworkAskPrompt`).
  - **Event details and deep links:** `get_in_app_events` always gives each event's `deepLink`, `purpose`,
    `priority` and `primaryLocale` (null when App Store Connect has none; App Store Connect refuses to take an
    event to App Review without a deep link), `missingForReview` (what's left before App Review, each `missing`,
    `queued` or `suggested`) and `readyForReview`, `deepLinkClaim` (whether the app's project folder declares the
    link's URL scheme in its Info.plist or its domain under `applinks:`, read by Atlas itself) and `deepLinkCheck`.
    `propose_event_details` queues a draft's deep link, purpose, priority or primary language, each a
    `PATCH /v1/appEvents/{id}` with that attribute alone that waits for the person's Accept; values App Store
    Connect would refuse are refused with the fix. `report_deep_link_check` keeps what the assistant found in the
    code (opens, what it shows and shows before the event starts, Premium, file:line, the build, Simulator,
    problems) for that event and deep link; the event's page and the Submit sheet show it, and its Check in the
    Code and Make It Work… start Claude Code with `InAppEventDeepLinkAskPrompt`.
  - **Make the Artwork** (board 47): `get_event_artwork_brief` reads what the person asked for in the sheet (the
    brief, the look, words and motion, the event's texts and names per language, the design, the rules, the
    concepts already in, and a change asked for one of them, with its images). `propose_event_artwork_concept` sends
    one concept as HTML pages or uploaded files; Atlas renders it per language (`{{eventName}}` filled in) and as a
    loop when asked, checks it and shows it in the sheet. Nothing is queued until the person uses it.
  - **Product Pages** (board 53, `Tools/ProductPages/`): `get_product_pages` reads the default page (the version
    pages start from, the last approved one, its promotional text and numbers) and every custom page as the section
    shows it, drafts made in Atlas included: link, visible, state and a newer version in review, each language's own
    promotional text, keywords and screenshots (`showsDefaultIn` the others), the deep link, the last 28 days'
    numbers from Analytics with the download rate against the default page (`tooFewToCompare` under 200 page
    views, no rate then), what's `queued` in Review & Push, and `takesTexts`. `keywords` has the approved version's
    keywords per language, `free` or `usedBy` a page (a keyword leads to one page); `pageLimit` counts pages of 70
    and the suggested pages waiting; `suggestions` lists the pages and texts sent over MCP as open, notOffered or
    dismissed with who sent them; `textRules` and `next` say what to do; past 20 pages the texts are left out
    (`pageId` reads one). `propose_product_page` keeps a whole page suggestion (`ProductPageSuggestion`: name,
    audience, reason, evidence, keywords and promotional text per language, `startFrom`, the screens' order and
    captions, deep link) for Dismiss and Accept in the section; it's refused, with every problem and its fix at
    once, without evidence Atlas can show (Analytics with numbers on this Mac, reviews it read, or the approved
    keywords the page chooses), for a keyword that isn't approved or that another page uses (naming it), a text
    over 170, a language the app doesn't have, a name another page or assistant has, a dismissed suggestion sent
    again, a caption App Review would reject, an incomplete deep link, or no room under 70 with the suggestions
    waiting. The same name from the same assistant replaces its suggestion. `propose_product_page_texts` keeps
    promotional texts for a page's or draft's languages (`ProductPageTextSuggestion`), skipping with why a language
    the app doesn't have, an empty or over-limit text, the page's own text, or a language with a text queued; a
    page with App Review or a key that can't change pages takes none, and an approved page's shows once the person
    presses Edit…. A promotional text App Review would reject (`StoreTextGuidelineCheck` for promotional text:
    prices, “free”, discounts, other platforms…) is never dropped: it's kept as Not offered with its phrases and
    `ProductPageTextRefusal`'s reason, returned in `notOffered`, and can't be accepted; a suggested page keeps
    them in `notOfferedTexts`, and the draft accepting it makes takes them into its languages
    (`ProductPagesStore.save`). Tools read the pages the section read while that's fresh
    (`KeptProductPagesServices`, `WorkspaceSectionModels.freshProductPages`), else App Store Connect. The section's
    count is the store's. Nothing is pushed, submitted or made visible by an assistant.
  - **A page's way through Review & Push and App Review** (board 54): Push and Submit… opens Review & Push on that
    page's changes (`ReviewScope.productPage`, `ReviewPageFocus`, set by `WorkspaceNavigator.review(page:)`), with
    the app and every app beside it. A page's version waiting for or in App Review is followed
    (`ProductPagesArchive.reviewStates`, `ProductPageReviewWatch`): each read of the section and each background
    check (`MainWindowBackground.checkProductPages`) tells In Review, Approved and Rejected once, as a toast and a
    notification under Settings → Notifications' review-status switch (`AtlasNotifications.productPagesMoved`).
  - **Choose Files…** (board 52's "not drawn"): PNG or JPEG screenshots the person has become a page's own set in one
    language on the device shown, checked first (`ProductPageFileCheck`: 1 to 10, iPhone 1320 × 2868, 1290 × 2796
    or 1260 × 2736, iPad 2064 × 2752 or 2048 × 2732, either way round), copied to
    `Application Support/Atlas/ProductPages/Files/<appID>/` (`ProductPageFilesFolder`, pruned once no queued change
    reads them) and queued as the same screenshots change Make Screenshots for This Page makes.
  - **Choose App Previews…**: 1 to 3 MOV/MP4/M4V videos per language and device, checked against `AppPreviewSpec`
    (`ProductPageVideoCheck`, sizes read with AVFoundation), queued as `.appPreviews` changes. The same
    `ProductPageScreenshotsPush` sends them, with `Content.media = .appPreviews` (`ProductPageMedia`: `appPreviewSets`
    with `previewType`, `appPreviews` with `mimeType`).
  - **Where the link is used**: Analytics keeps the Detailed reports' Source Info and Campaign
    (`EngagementFact.referrer/campaign`), Break It Down splits by `referrer` and `campaign`, and each page's numbers
    carry `ProductPageArrival`s (the row's "Most from …" line, `get_product_pages` → `numbers.arrivals`).
  - **Pushing a new page against Apple (2026-11-21, Alba)**: the create request lists the draft's languages inline
    (Apple requires `appCustomProductPageLocalizations` even with a template, and refuses an inline ID in the
    localization's link back to the version). Writes wait 300 s (`AppStoreConnectClient.writeTimeout`); a timed-out
    write is Failed, never Not sent. A draft Apple made anyway is taken as that page on the next read
    (`adoptCreatedDrafts`), and a queued create change from an older Atlas is rebuilt (`refreshDraftChanges`).
  - **Look and Capture Screens Again** (board 52's Plan): `PageShotsRun.design` (`PageShotsLook`: the default
    template, a starter, or `.claudeDesign` with three `PageShotsLookCandidate`s from `propose_page_look`, laid on
    `base` default or a starter and checked by `MCPDirectionTemplate`; Start waits for one to be chosen) and
    `PageShotsRun.recapture` (`PageShotsNewCapture`s at most 3 screens, PNGs posted to
    `/page-shots/<token>` and named with `report_page_capture`, full device size only; a language without its own
    uses the primary's). `PageShotsSource.applying(run)` lays the set out with both; each asks Claude Code in a
    session of its own (`PageShotsPrompt.looks` / `.captures`). DEBUG scenes `cp-shots-looks`,
    `cp-shots-looks-drawing`.
  - No other devices: custom product pages are iPhone and iPad only, and smaller sizes are scaled from 6.9″ and 13″.
  - There is no tool to submit a version or release it: those are the person's.
  - **Analytics:** `get_analytics_funnel`, `get_analytics_breakdown` (by territory, language, source, device or
    product page) and `get_analytics_subscriptions` read what Atlas downloaded; they never ask Apple. Every rate
    comes with its counts, its 90% range and `tooFewToTell` when it shouldn't be quoted, and `notes` say what's
    missing. `add_finding` puts a finding in What to Try, marked as the assistant's; the fix itself still goes through
    the propose_ and suggest_ tools.
- **Prompts:** `translate_missing`, `whats_new_from_git`, `fill_privacy_from_code`, `fill_age_rating`, `fill_compliance`,
  `translate_captions`, `shorten_overflowing_captions`, `revise_template`, `suggest` (with an optional `area`,
  `store` or `info`), `suggest_all`, Suggest Everything's, and `run_screenshots`, Screenshot Autopilot's. A prompt is offered only while its
  tools are.
- **Clients:**
  - Cursor connects over HTTP.
  - Claude Code, Claude Desktop and Codex launch servers as processes, so they run the bundled bridge,
    `Atlas.app/Contents/MacOS/atlas-mcp --token <token>`. It forwards stdio to the HTTP endpoint and
    starts a new session on its own when the app relaunches. Once the client is initialized it opens the
    session's `GET` event stream, so Atlas's `roots/list` reaches the client and Atlas learns its project folder.
  - Claude Code goes through the bridge, not HTTP: an HTTP server that failed as the session started (Atlas
    closed) stays failed until `/mcp`, while the bridge always starts. When nothing listens on the port, the
    bridge opens Atlas in the background (`MCPBridgeAppLauncher`: the Atlas.app it's in, else the one Launch
    Services knows) and the request waits up to 20 s for its server. An Atlas open for over 20 s isn't
    waited for: its server is off. Only a refused connection is tried again, since nothing was sent.
  - Runs Atlas starts itself (`ClaudeCodeInvocation`) still pass an HTTP `--mcp-config`: Atlas is open then.

### Starting Claude Code from Atlas

The app is sandboxed for the Mac App Store, so it can't start other programs. Instead, the person saves a small helper
once, from a Save panel already in `~/Library/Application Scripts/com.lima.atlas/` (setup's step 3, Settings →
AI Assistants, or the "Skip the paste" hints). macOS runs scripts there outside the sandbox with `NSUserUnixTask`, so
no new entitlement is needed (`Managers/ClaudeCodeLauncher/`).

- **The helper** (`ClaudeCodeHelperScript`): `check` prints its version and where `claude` is; `run <folder> --
  <arguments…>` runs Claude Code in the app's project folder, streams its output and prints
  `atlas-helper-exit <status>` when it ends. Claude Code writes through pipes of its own that `cat` passes on:
  Node leaves the pipe it writes to non-blocking, which on Atlas's pipe lost a run's last lines and its exit
  line (helper version 1). Atlas reads stdout and stderr each on its own (`PipeLineReader`), never with
  `FileHandle.bytes`: that reads every handle in the process on one serial queue, so an idle stderr stopped stdout
  from being read, the pipe filled and the helper waited forever on its last line, holding back every later call.
  A run whose helper hasn't ended a minute after Claude Code's result ends anyway (`ClaudeCodeLauncher.resultGrace`).
  A line on stdin, or stdin closing, ends Claude Code with SIGTERM (a script's background job
  ignores SIGINT); the session stays resumable. A helper older than `version` asks to be saved again. Version 3
  adds Autopilot's simulator modes, each a fixed command with checked arguments: `simulators` (`xcrun simctl list
  -j runtimes devicetypes devices`), `install-platform <iOS|watchOS|visionOS|tvOS>` (`xcodebuild -downloadPlatform`)
  and `create-simulator <name> <type> <runtime>` (`xcrun simctl create`, only `SimDeviceType`/`SimRuntime` ids).
  Version 4 adds iPhone Duo's, each on a simulator (and display) checked to be a UUID and with a time limit, as a
  stuck simulator can keep `simctl` waiting: `simulator-displays` (`simctl io enumerate`), `simulator-screenshot`
  (one display, shrunk to 256 pixels with `sips` and printed as base64), `simulator-crashes` (its SpringBoard crash
  reports written since it started, i.e. newer than its `launchd_bootstrap.plist`), `boot-simulator` (`simctl
  bootstatus -b`) and `shutdown-simulator`. Version 5 adds `open-duo <udid> <name>`, which opens iPhone Duo (below),
  and `accessibility [prompt]`, which says whether it may (and with `prompt`, has macOS ask the person). Version 6
  adds recording a display: `record-display <udid> <display>` screenshots one display with `simctl io` over and over
  into a new `mktemp` folder, printing `folder`, `frame <start> <end> <file>` (when each capture began and ended) and
  `same <end>` (a frame like the last, not kept), until a line arrives on its stdin or stdin closes, for at most ten
  minutes; `test-results <bundle.xcresult> [<test>]` prints `xcresulttool get test-results tests` (or one test's
  `activities`); `recorded-frame <frame>` prints one frame as base64 and `discard-recording <folder>` deletes one.
- **This Mac's simulators** (`Managers/Simulators/`): Autopilot's plan checks, through the helper, that each planned
  device has a simulator (`SimulatorInventory`, `SimulatorStatus`): ready, one to make, a runtime to install (iPhone
  Duo needs iOS 27.1 or later; Xcode 27.2 may come with only iOS 27.0), or a newer Xcode. "Install the iOS
  Simulator" downloads the platform, then makes the simulator (`MacSimulators`). Starting with a device still
  missing reports it as one problem for the device (`AutopilotCenter.reportMissingSimulators`), and so does looking
  at a run that's capturing, or continuing it. A simulator that's only missing (`.canMake`: the device type and a
  runtime that runs it are installed) is made by Atlas itself in any run (`Managers/Simulators/RunPreparation/`):
  `AutopilotCenter.prepareSimulators` before the run goes to the assistant (Start, Continue, a capture-only run
  accepted or opened by `request_recapture`; `request_page_recapture` makes the page's device's), and
  `makeMissingSimulators` mid-run, where `next_step` answers `wait` ("Atlas is making the iPhone Duo simulator")
  instead of telling the assistant to report it. `SimulatorMaker` (`MacSimulators.maker`) makes one per device at
  a time and doesn't retry one that failed (that's a device-wide problem with `create-simulator`'s message). An
  open device-wide "no simulator" problem (`AutopilotProblem.isAboutMissingSimulator`) on a device that has its
  simulator now, or can make it, is resolved `.solvedByAtlas` and its targets go back to `next_step`.
  `get_capture_plan`'s `devices[].simulator` is `ready`, `making` or `needsRuntime` (the name is `simulatorName`);
  only `needsRuntime` is reported with `affectsDevice`. Debug scene `ap-recapture-make-duo`
  (`DebugSimulators.runWithDuoToMake`). Retrying a device this Mac still can't run brings its problem back
  without starting Claude Code: a retry waits while its device has an open device-wide problem. iPhone Duo's
  simulator starts closed (only the outer 1398 × 2034 display shows the app; a UI test's `XCUIScreen.main` is that
  cover display even once it's open) and nothing public opens it: not `simctl`, `devicectl` or XCTest; Xcode 27.2's
  Device Hub (`DeviceHub`, `com.apple.dt.Devices`) does, in the device's poses. So Atlas watches the Duo
  (`Managers/Simulators/Duo/`, `DuoWatcher`): every few seconds it finds the inner display by its size
  (`SimulatorDisplayList`), screenshots it and tells black (closed), a faint spinner in the middle (starting, or
  stuck) and anything else (open) apart (`DuoInnerDisplay`). `DuoStep` decides: during a run it starts a Duo that
  isn't running and opens a closed one; it restarts a stuck one, whose SpringBoard crashed since it started or whose
  spinner lasted 90 seconds, at most twice in a row, then asks the person to erase it; it never restarts an open
  one, as starting it again closes it. To open it, the helper's `open-duo` opens the Duo's own window in Device Hub
  (`devices://device/open?id=<udid>`; `DeviceHub.windowLink`), presses Open in its poses through Accessibility (a
  small Swift program run with `xcrun swift`: Device Hub shows its windows to Accessibility only while it's in
  front, so it goes in front, then closes that window, hides Device Hub if it started it, and puts the app that was
  in front back, found with `lsappinfo`, as `NSWorkspace` gives scripts no pids here). It never quits Device Hub,
  which can shut down the simulators it started. The open inner display captures at 2853 × 2007. That needs
  Atlas allowed in Privacy & Security › Accessibility (the helper runs as Atlas's): macOS asks once,
  the card and the plan say so with Open Accessibility Settings (`AccessibilitySettings`), and the watcher tries
  again once it's allowed. Two failed tries, and the card asks the person to open it in Device Hub. The assistant
  reports a closed or stuck Duo as one device-wide problem; its card shows what Atlas sees in place of the
  assistant's fix, and once the Duo is open the run tries it again without a Retry (only after seeing it closed, so
  a Duo that was open all along can't loop). The plan's row says whether it's open, with Open Now. Starts,
  restarts, presses and the opening go in the run's log. With a version 4 helper it can't open it: the card asks
  to save the helper again and opens Device Hub; older than version 4, the card keeps the assistant's fix and
  says how to restart a stuck Duo by hand. A UI test's screenshot being the cover display, and the test closing the
  app about two seconds after its screen appears (too soon to screenshot the inner display after it), Atlas
  records the inner display while the test runs (`Managers/Simulators/Recording/`, `DisplayRecorder`, through the
  helper's `record-display`: a frame about every 0.6 seconds). Afterwards `XcresultTimeline` reads from the test's
  result bundle when it attached each screenshot (the attachment's `timestamp`), when the step before it began and
  which simulator it ran on, and `RecordedFramePick` keeps the last frame that finished before that moment (one that
  began before that step isn't settled); the rest are deleted. The project needs no change.
- **Keeping a run going** (`Managers/Autopilot/Continuation/`): when the Claude Code Atlas started for a run
  ends with work left and sent something since it started, Atlas starts it again with the prompt that
  continues the run (`AutopilotContinuation`, through `ClaudeCodeLauncher.onRunEnded`); one that sent nothing isn't,
  so it can't loop. A run nobody works on says so in the sheet (`AutopilotStall`: Claude Code ended, with its last
  words; Atlas was closed; or nothing arrived for 30 minutes after a paste), with Continue. Answering a
  problem continues the run too, when Atlas started Claude Code for it, and so does each step that gives
  the assistant work again: Use These Picks, Use This Direction and Ask for Changes (`AutopilotContinuation.keepGoing`).
  A Claude Code that ended on the person's turn (before that step, `AutopilotRun.handedBackAt`) didn't stop with
  work left, so the sheet never says it stopped; without the helper the footer says it's Claude Code's turn, with
  Continue. These steps' tasks hold the center and the app, never the studio, whose view model is unowned and
  can go away with the section. The sheet says it in the stage's words (`AutopilotStall+Wording`: captures left,
  directions still to design, your changes still to make); only a stop or a silence is drawn as a warning, and a
  run Atlas was closed on is paused, not stopped. A pasted run goes quiet counting from the person's last
  step or the brief's reading too (`AutopilotRun.lastActivityAt`), so picking for an hour doesn't make the design
  quiet. Design shows the same status as Capture (`AutopilotAssistantStatus`: what Claude Code is doing now, for
  how long, Show Output and Stop, or why nobody is, with Continue), how many directions arrived, and cards that
  only spin while someone works (`AutopilotDirectionCard`: the next one designing and for how long, the ones after
  it up next, all waiting while nobody works); the stage's own spinner stops too. Localize says the same: how many
  screenshots are ready, which language this Mac is checking, the captions out to Claude Code (`AutopilotCaptionWork`:
  missing ones to translate told apart from ones too long, per language and in all) and what it's writing, with
  each language's row spinning only while someone works on it. A version 2 helper still starts
  Claude Code (`minimumRunVersion`) and asks to be saved again for the simulator modes and iPhone Duo.
- **Each run** (`ClaudeCodeInvocation`) is `claude -p --output-format stream-json --verbose --restricted
  --strict-mcp-config --mcp-config … --settings … --permission-mode dontAsk --tools …`. It knows only Atlas's
  server, with a token made for that run that acts as the paired Claude Code and stops working when the run ends
  (`MCPServerController+Launch`). The person's own settings and allow rules are ignored, and anything not allowed is
  refused and listed. `ClaudeCodePermissions`: setup's test uses only Atlas's tools; suggestions, translations
  and the privacy scan also read the project and run read-only git; Autopilot also runs `xcodebuild`, `xcrun simctl`
  and uploads to Atlas. Each command must start with an allowed program, so `VAR=value xcodebuild …` is
  refused; Autopilot is told so. Its one deny rule is `xcrun simctl io … screenConfig`: an assistant powered iPhone
  Duo's displays off and on to open it, and the simulator's SpringBoard crashed on every start until it restarted.
- **Where:** Ask on every suggestion bar, Suggest Everything, Screenshot Autopilot, Translate Missing, Translate
  Captions, App Privacy's scan, and setup's test. Each app's project folder is asked for once, and Settings lists
  them. Without the helper, every screen copies its prompt as before.
- **Seeing it:** a status strip where it started, the Autopilot menu's status popover, and Show Output with each step, the
  result, refused steps and Copy Resume Command (`ClaudeCodeRun`). A failure says why (not logged in, no Claude Code,
  folder moved, Atlas unreachable) with the way through: Open in Terminal (Claude Code's `claude-cli://open`
  link), Try Again or Choose Folder…, and Copy Prompt.
- Claude Code uses the person's own login and plan.

## Tests

- **Unit tests:** `AtlasTests`, written with Swift Testing. They cover:
  - JWT signing and verification;
  - the client's requests, pagination and errors;
  - credentials validation;
  - the Keychain round trip, under a throwaway service name;
  - the session and the view models;
  - the AI providers' requests and replies;
  - the screenshot fit engine, renders, the Captures tab's viewer and its images (kept within a pixel budget, the
    oldest first), the push plan and its uploads, backups and restores;
  - the MCP server (HTTP parsing, JSON-RPC, pairing, sessions, tools and prompts) and the stdio bridge;
  - field suggestions: the store, the built-in checks, accepting and undoing on both pages, and the setup sheet;
  - Settings (board 48): the panes and their search, the new preferences and Reset, notifications (what is sent,
    when, the Dock count), Atlas Pro's plan row, what assistants may suggest, the activity and the local data
    (never deleted in tests); Atlas Help (board 49): the parser, every bundled article, search, navigation, and the
    scenes;
  - Suggest Everything: what it covers and its prompt, the run's plan, progress and end, Accept All and its Undo,
    and the toasts;
  - the API key: each vendor's models and requests, the project folder's commits and changelog, the plan and its
    tokens, reading the answer, and adding what passes to the Store Page;
  - Screenshot Autopilot: the run's stages, captures, problems and picks, the planner and estimate, caption checks
    and direction pills, brand folders, the MCP tools and the upload endpoint, and the App Store preview and its
    Live/New set summaries; Apple Watch and Apple Vision Pro (their screens, layouts, checks, previews and pushes to
    the visionOS version), iPhone Duo (its sizes, checks, canvas, row and plan) and the project's new languages;
    this Mac's simulators (reading `simctl`'s list, what each device needs, installing and making one, a device-wide
    problem, leaving a device out, and iPhone Duo's watcher: its displays, closed or stuck or open, restarting,
    starting and opening it, and asking for Accessibility, and recording its inner display during a UI test: the
    helper's recording lines, the result bundle's timeline, each screenshot's frame and the two MCP tools); keeping a run going (the rehearsal per screen and device, starting Claude Code
    again only after progress, a run nobody works on, recapturing a screen reported out of date, what the sheet says
    in each stage's words, a paused run that isn't a warning, Design's cards and the brief's reading, Localize's
    captions to write, and each device's canvas turned the way its captures are);
  - Claude Code started by Atlas: the helper's answers and exit line, each run's arguments and permissions,
    reading the stream, failures, the Terminal link, runs through a pretend helper (folders, run tokens, Stop, Try
    Again, login and server problems), and setup's test run.
  - Analytics: rates, ranges and verdicts; reading Apple's report files (gzip, tab- and comma-separated, by column
    name); the facts kept on this Mac; the funnel, breakdown, subscriptions, changes and findings; the store's asking,
    refreshing and files; the view model; the MCP tools; and the requests sent to Apple.
  - Navigation: the sections' order, groups and shortcuts, each section's count, the toolbar with and without the
    sidebar, and the sidebar's version status.
  - Ratings & Reviews: the store and its files, the list's filters and sorting, sending, Undo and dismissing, Free,
    translation and languages to download, Reply to All, the ratings summary and the version comparison, the
    requests sent to Apple, and the MCP tools.
  - Submit for Review and release: App Store Connect's states as phases, which version is followed, the card's
    checks and steps, what the sheet says is missing, the plan a submission sends and each request in order, every
    action after submitting, what's remembered between launches, and what's announced.
  - In-App Events: what an event still needs, its languages, editing, accepting and undoing suggestions, new and
    duplicated events, the changes queued for Review & Push, reading events from Apple, and the MCP tools.
- **UI tests:** `AtlasUITests`, written with XCUITest, run against the DEBUG scenes.

Run everything with `xcodebuild -scheme Atlas -destination 'platform=macOS' test`.

## Lint & formatting

The project is kept warning-free.

- Install the tools once: `brew install swiftlint swiftformat`.
- The `Atlas` target's **Lint** build phase runs `swiftformat --lint` and `swiftlint lint` on every local build.
  - Findings show up as Xcode warnings.
  - The phase is skipped on Xcode Cloud, where the tools aren't installed.
- Format everything with `swiftformat .` from the repo root. `MCPBridge/` is linted too. The configs are `.swiftformat` and `.swiftlint.yml`, the same rules as Bruma.

### Build settings worth knowing

- `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the `Atlas` target lets the Lint phase read the sources.
- The App Sandbox is on, with three exceptions:
  - outgoing connections (`ENABLE_OUTGOING_NETWORK_CONNECTIONS`), for the API and the AI provider;
  - incoming connections (`ENABLE_INCOMING_NETWORK_CONNECTIONS`), for the local MCP server;
  - user-selected files, read and write (`ENABLE_USER_SELECTED_FILES`), to import the `.p8` and listings, and to
    export listings.
- The `atlas-mcp` target is sandboxed on its own, with outgoing connections only, because assistants launch it
  without the app.
  - `CREATE_INFOPLIST_SECTION_IN_BINARY` embeds the Info.plist that a sandboxed tool needs.
  - The app's **Embed Command Line Tool** phase copies the tool into `Contents/MacOS` and signs it.
- `LM_SKIP_METADATA_EXTRACTION = YES` (project level) silences Xcode's "Metadata extraction skipped, no AppIntents.framework dependency found" warning. **Remove it if the app ever adopts App Intents.**
