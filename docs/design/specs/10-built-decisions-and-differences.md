ATLAS · WHAT THE APP DOES NOW · 22 NOVEMBER 2026

# Built in the app, and where it differs from these boards

Everything built since the last sync (5 November, commit e752b83) up to 22 November (commits 21da68f, 7cb87c0, 91ab428, 774c109, and the Autopilot button’s animation and the fixes after it), with every decision that departs from a board and why. Start the next design revision from here, not from the boards alone.

**How to read it.** Board numbers are the canvas’s. “As drawn” means nothing worth knowing differs. Most deviations come from Apple’s API (checked against the App Store Connect OpenAPI spec 4.6/4.6.1) or from live runs on Alba, Bruma, MB Admin and SimProps. Older “Built since” notes stay in README — screenshot studio §6–§9 and README — suggestions §9.

## 1 · At a glance

| Area | Boards | State in the app |
| --- | --- | --- |
| Guided Autopilot | 21, StudioV2 | Built. It is now the only Autopilot: the Classic sheet and its Settings switch are gone |
| Template gallery | 23, Templates · 14 | Built: 14 templates with Social Proof and Arcade |
| Retention | 28 | Built |
| Redesign proposal | Proposta · Novo design | Built across the app |
| Paywall, Free and Pro | Paywall · every state | Built in part (see §4) |
| Analytics | 29–37 | Built, with Apple’s limits |
| Ratings & Reviews, Submit and release, In-App Events | 38–40 | Built; the events page was redone with 47 |
| Navigation in the sidebar | 41–43 | Built |
| App Compliance | 44 | Built; most answers can’t be pushed |
| Welcome and menu bar | 45–46 | Built |
| In-App Event artwork | 47 | Built, inside the event page |
| Settings and Help | 48–49 | Built; a few rows left out |
| Custom Product Pages | 50–55 | Built, 52 included (Look, Capture Screens Again, Choose Files, App Previews) |
| Ask Claude Code → toolbar | 56 | Built, not yet from Product Pages or In-App Events |
| Toolbar, Autopilot and Review & Push | 57 | Built, with “While it works”: the button’s animation (22 Nov) |
| Reply to reviews automatically (Pro) | 58 | Built; its first real send hasn’t reached Apple (§5) |
| Screenshots by hand | README — Manual, Redesign · Screenshots | Built (22 Nov); its tests are written, not run yet |
| Recapture only some captures | none yet | Built (§6) |

## 2 · Decisions and deviations, by area

### Screenshot Autopilot (guided)

- **One Autopilot.** The guided sheet (What to make → Look → Plan → Making it → Choose → Review & push) replaced Classic.
- **Kept from the first version:** Choose… for languages, the artwork size menu on Look, Edit Captions… on the screenshots tab, asking for changes after Localize only at Watch, and Pick only when it is turned on. There is no “On the App Store now” line in the header.
- **Look shows every device the app ships on** (iPhone, iPad, iPhone Duo, Mac, Apple Vision Pro, Apple Watch). A device the run doesn’t make is dimmed with “Add it to the Run”. Duo, Mac and Vision borrow the iPad captures in the preview.
- **Mac is a full Autopilot device.** Its capture is this Mac’s whole screen (about 16:10, at least 1280 × 800), drawn in a MacBook frame and pushed to the macOS version.
- **Without a design project, Claude designs the looks and the header concepts** from the app’s own design (its design docs, theme, icon). A Plan switch turns it off for Atlas’s starters. People asked for “the design we already have in the app”.
- **The art’s author is called “Claude”,** not “Claude Design”, everywhere the app names who designs. Claude Design stays only as a kind of design project.
- **Proposals outside a run.** New screens and plan changes sent when no run is at Plan wait for the next plan. They show in a “Sent for this plan” card at the top of Plan, with Add, Accept and Reject. Fixes are split into commands (xcrun, xcodebuild) and notes, each with Remove.
- **Problem cards gained:** Retry in Every Language, Keep the Capture, Fix It (Atlas repairs the Simulator through the helper), Install / Leave the device out for a device-wide problem. When Claude hits its usage limit, Autopilot waits for the reset and goes on by itself. An intentional stop is never shown as an error.
- **App Preview:** each moment’s motion is measured, and a still one is recorded again once on its own. Home Screen and white launch frames are cut. Four more music moods. Claude answers questions about the app once a run; the answers are kept for 120 days.
- **Captions follow their screen by name** when screens are reordered. A live run had rotated the captions in 13 languages.
- **iPhone Duo uses its real frame**, taken from Xcode’s device masks: square on the hinge side, round on the other; the cover display never bleeds off the canvas.
- **Review:** a Social Proof reviews slot with no reviews shows its capture with a warning instead of blocking the push. A ready run that wasn’t pushed has New Run…. A header that failed has Make Again.

### Templates

- 14 templates, Social Proof and Arcade included. Arcade’s Boldonse font has no Cyrillic, Greek or CJK: those languages fall back at weight 800.
- 3D device frames for every template. Laurels show the App Store rating in each country; a typed value stays and is checked.
- Gap: in the caption editor and proposal previews, Two phones’ back phone shows a black screen.

### Redesign proposal

- As drawn: suggestion tints, count badges, the Accept All sheet, the language bar on Store Page and Screenshots, Overview, Pricing product cards.
- Badges count only what a section really shows. Alba had 52 open suggestions but 24 were URLs the fields already held.

### Navigation (41–43)

- Sections in the sidebar, apps in a popover at its top, the version’s status in its footer. Custom Product Pages joined Store Listing.
- No Add App…. App search appears only above 8 apps.
- At 860 pt with the sidebar open, the title and some labels fold into the toolbar’s overflow menu. The 860 board has the sidebar hidden.
- Added: sections not on screen are read ahead in the background, one at a time, and stop when Apple’s hourly limit runs low.

### Ratings, release and In-App Events (38–40, 47)

- App Review’s rejection message and “reset the rating summary” aren’t in Apple’s API: the card explains and links to App Store Connect.
- Ended events’ numbers aren’t read (link to App Analytics). The ratings average comes from each storefront’s public lookup.
- Confirmations added for Cancel Submission, Release Now, Release to Everyone and Submit Event.
- The Submit sheet reads builds again on opening, every minute and on Check Again, and shows when each build was uploaded.
- **Events page:** a gallery, then one page per event with the store preview and the Artwork panel side by side. The Brief is the only sheet; Make closes it. The viewer covers the whole window. Deviations: Submit stays off until the event is pushed; Make Them Move stays in the panel; a Replace menu when an event has both images; the viewer also offers suggested languages; the narrow 860 × 560 states aren’t built.
- **Added after Apple refused Alba’s events:** a Details card (deep link, purpose, priority, primary language), a “Before App Review” list where each missing thing has its fix, a check that reads the Xcode project for the app’s URL schemes and app links, and two asks: Check in the Code (read-only) and Make It Work… (may edit the project). Date pickers on drafts follow Apple’s rules (future dates, 15 min to 31 days, card at most 14 days ahead) and warn when App Review may need up to 48 hours.
- Assistants’ revisions show Now and Suggested with the changed words marked. Dismiss All, with undo.
- **Event art:** the brief is written from the event’s texts; templates are text layouts; words in the art follow each language. Art goes to the primary language unless a language needs its own: copying it into every language made 59 needless uploads on Alba, so that was removed.

### App Compliance (44)

- Apple’s API has nothing to write the trader status, the ICP filing number, Vietnam’s game license or the medical device declaration. Trader and ICP answers are kept on this Mac with “Enter in App Store Connect”, Copy and Open App Store Connect. Vietnam and medical device use Mark as Declared. Only “Stop selling in China mainland” is a real Review & Push change.
- The medical device rule follows Apple’s help page (the secondary category counts too), so the sample shows 3 that need you, not the board’s 2.
- Added: China mainland’s security assessment and AI-generated content declarations. App Store Connect asks them even when China is off, so Atlas does too, answered No outside China. An assistant’s answers are accepted one by one, never by Accept All.

### Analytics (29–37)

- Sales stay on Sales and Trends (vendor number): Apple’s analytics reports drop rows under five people, which would hide most of a small app’s subscriptions.
- No product page optimization results: the reports have no treatment column. By Product Page shows the default and custom pages.
- “Half cancel in the first renewal week” became “before the first renewal”.
- Added: the referring app or website and the campaign from the Detailed reports, in Break It Down and as “Most from …” on each product page. An empty split says why.

### Welcome and menu bar (45–46)

- As drawn. Closing the window hides it; Atlas keeps running in the menu bar and checks App Store Connect every hour unless it is set to Only When I Ask.
- ⌘Q works with a sheet open: it closes the sheets and asks only while something is being pushed.

### Settings and Help (48–49)

- Left out: the Simulator and Autopilot rows in Screenshots (Atlas can’t choose Xcode or quit the Simulator), the “Accept right away” rows, the too-long / Analytics / translate-offline check rows, “Help improve Atlas” (Atlas has no telemetry), Update Price Data, and What’s New in Atlas. The cache row covers renders and ratings only. The vendor number shows only for the key in use. The support email isn’t set yet.
- The sidebar is plain buttons, as the markup has them. All 19 articles ship, Product Pages’ included.
- Not drawn and not built: the small ? beside a section’s title, and error messages that link to Fix a problem.

### Custom Product Pages (50–55)

- Push and Submit… opens Review & Push limited to that page, not a push sheet of its own (the cp-push states aren’t built). After the push, Submit for Review opens by itself, and Atlas follows App Review and notifies when the page moves.
- “Make visible when approved” is kept on this Mac and queued once the page is approved. Cancel Submission works only when the submission holds only this page.
- No “link use” column and no dates in the banners: Apple gives no data for them.
- **Screenshots for a page (52)** is a studio of its own: Plan, Making, Result, then Use These Screenshots queues the set. Look: the default page’s template, another starter, or three looks from Claude. Capture Screens Again: Claude Code builds the app and captures up to 3 screens (it may run the project’s screenshot UI tests); a language without its own capture uses the primary one; captures follow the template’s orientation. Also Choose Files… and Choose App Previews…. Devices are iPhone 6.9″ and iPad 13″ only: product pages are iPhone and iPad only.
- An accepted suggestion’s brief (audience and screens) is kept by page name and shows under the screenshots. Submit warns when a page has keywords but no screenshots of its own.
- Live on Alba: creating a page from a 14-language template takes Apple more than a minute, so writes wait 5 minutes and a page Apple made after a timeout is adopted.

### Ask Claude Code → toolbar (56)

- As drawn for the sections’ Ask buttons. A run that failed or had refused steps reopens the button’s popover.
- Not yet: Product Pages’ Suggest Pages and Ask Claude Code for Ideas, and In-App Events’ Ask.

### Toolbar, Autopilot and Review & Push (57)

- As drawn: the title and status in the toolbar, “3 not pushed” opening Review & Push for that section, one Autopilot split button per section with its menu, Approve All, the language menu in the toolbar. Labels fold to icons at 860 pt.
- **Built by hand.** A toolbar menu button on macOS draws only an icon and a title, so the split is a button with its own label plus the arrow’s menu, on their own glass capsule. It looks like the other toolbar glass, and the light can run along its real edge.
- **The toolbar has the window’s color,** not the page showing through: with the soft edge alone, a scrolled page’s text sat behind the title (Alba’s Overview). Autopilot, Refresh and Activity, and Review & Push are all 36 pt tall.
- **“You’re offline”** shows only while the Mac really has no network and leaves by itself when it comes back. A timeout while online is said by the section or the push row. It used to stay until the next push.
- **Sidebar:** where Autopilot waits for you, a solid purple sparkle comes before the section’s count: Screenshots at Pick, Choose or Review; Reviews when Reply Automatically left replies.

### While it works: the button’s animation (57)

- **As drawn,** with the README’s timing: the purple light crosses the edge every 2.2 s, linear; the sparkle’s two stars shrink to half, turn 45° and fade to 40% every 1.5 s, ease in-out, the small one half a cycle later; the 2 pt bar eases to each value in 0.7 s; the green check draws itself in 0.35 s (SF Symbols’ Draw On, macOS 26) with one 0.45 s bounce, and stays about 2 s. Idle, needs you and failed are still.
- **Only counted progress gets a bar:** the guided screenshot run’s captures, recordings, looks and languages. Starting Claude Code and picking the screens have no bar (Making it’s bar still shows a sliver there). An Ask request has no bar.
- **Done** shows only when a run ends by itself: not when it now needs you, nor when it failed. The words follow what ran: “Working · Store Page · German” becomes “Done · Store Page · German”; a run with no subject says “Done”.
- **Failed** is the app’s last Claude Code run that stopped with a problem, in its words (“Claude Code couldn’t reach Atlas”, “Claude Code needs you to log in”). A click opens Show Output with the reason; closing it forgets the run and the button is idle again.
- **Needs you** uses the suggestion badge’s purple, with dark text in dark mode (as the count badges).
- Reduce Motion: a steady purple outline, the small star dimmed, the bar jumps to its value, the check appears at once, no bounce. VoiceOver: “Autopilot, making screenshots, 5 of 10 captures, 55 percent”; start and Done are announced once.
- The menu bar icon already moved for the same runs. A run in another app doesn’t animate this window’s button.

### Autopilot only approves (22 Nov)

- The guided run’s last step is now **Review & approve**. Approve All closes Autopilot with a toast; the set, its App Previews and art wait in the app-wide Review & Push with everything else, and pushing happens only there. Nothing opens by itself.
- Done says “Waiting in Review & Push”, “Pushing from Review & Push” (Show Progress…), “Sent to the App Store” or “Not everything was sent”, with Open Review & Push… — no progress bars or Try Again of its own. An approved run no longer shows “needs you” in the toolbar, the menu bar or the sidebar.
- Product page screenshots and capture-only runs already worked this way.

### Reply to reviews automatically (58)

- As drawn: Draft and tell me, or send the ones you allow; ratings, topics that always wait, delay, tone and an example; the strip, History with Undo, Pause from the strip, the menu or the menu bar; notifications with Open Reply.
- **Safety gate:** nothing is sent by itself until one reply sent by hand has gone through, since Send Reply has never been tried against Apple. A daily cap applies.
- Only reviews after it was turned on, at most 7 days old. Claude Code is started for it only when the app has a project folder; it never opens a folder panel unattended.

### Screenshots by hand (README — Manual)

- As drawn: on a language’s page, click a screenshot to get the bar (◀ ▶, Replace…, Delete…, Undo Change, where it comes from); the Add Screenshots tile and drop; Manage with Add, Import a Folder… and Delete All; “Uses English (U.S.)” with Start from English. Replace and Delete work in one language or every language with its own screenshots.
- **Never scaled.** A file must be one of the device’s sizes, upright or turned, without transparency; anything else is refused with the sizes to use.
- **Push order:** uploads first, deletes only once every upload went (each deleted one is copied first), then the new order. A failed upload never leaves a language with fewer screenshots.
- Import a Folder reads fastlane’s layout; the device comes from the folder or file name, else from the pixel size, and the order from the leading number. A table says what happens to each language first.
- Claude Code can suggest a file for a place (`propose_screenshot_file`, through an upload link); it waits on the language page with Accept and Dismiss. Assistants never delete screenshots.
- The primary language keeps at least one screenshot per device.

### Review & Push

- **A new product page after Apple’s 500** (Alba’s “Affirmations & Confidence”: UNEXPECTED\_ERROR on the create). Atlas looks for the page by name for about 2 minutes (“Looking for … in App Store Connect…”); found, it takes it, makes the languages Apple didn’t, and the keywords and texts go on. It never sends the create again by itself (that could make two pages). Not found: the message says Apple may still be making it and to wait before retrying. A later step that fails is named (“… is in App Store Connect, but Keywords · German didn’t go in”). A language write that gets a 5xx is retried once. Only a 5xx or a timeout says “may have gone through”. Not yet tried against Apple.
- **One progress sheet** for texts, screenshots and extras (bulk review replies keep their own). Title like “Pushing 12 changes and 40 images”, one row layout, a thumbnail per image that opens the full-size viewer, Cancel Remaining and Retry Failed for everything.
- **Several at once:** up to 8 changes in flight and 12 uploads waiting on Apple’s processing; nothing waits for Apple before the next item starts.
- **Minimize (Esc):** the toolbar button bounces and shows “sent / total”.
- A write that timed out is Failed, never “Not sent”.
- Gaps: an App Preview plays muted in the viewer; no Live Now | New comparison in the progress viewer.

## 3 · Built in the app with no board

| What | Where it shows |
| --- | --- |
| **App Review’s metadata rules.** Texts Apple would reject (prices, “free” in any language, trials, other platforms, “#1”/“best”, beta or coming soon, placeholders, “For Kids”) are refused from assistants and warned under the field and in Review & Push. Events, retention messages, review replies and in-app purchase texts each have their own rules | Every text editor, Review & Push, the assistant’s tools |
| **New Version…** queues a new App Store version; texts written for it join its “Create version” row and wait for it | Store Page, Review & Push |
| **Review notes** for each in-app purchase and subscription, read and suggested by assistants | Store Page → In-App Texts |
| **In-app purchase prices**, read only: See Prices…, Free for tier 0 | Pricing, Overview |
| **An honest connection per app**: connected here, connected to another project, unsure (Choose Folder…), can’t connect (Reconnect…) | Overview’s assistant card, assistant popover |
| **Image loading tiles** wherever an image loads, never a spinner forever | Everywhere |
| **Missing simulators made by Atlas.** When Xcode knows the device and its runtime is installed, any run (a capture-only one too) makes the simulator itself, logs it, and the problem card goes away. Only a runtime to download, an old helper or a failed make reaches the person | Autopilot’s Making it, Claude Code’s `next_step` (waits instead of asking for a report) |
| **Version states** App Store Connect has (Ready for Review and others) are read; an unknown one is named in the message | Store Page, App Information |

## 4 · Not built yet

- Paywall: the 3-template and per-device limits of Free, and the gate on a second App Store Connect account. The Pro products don’t exist in App Store Connect yet, and there is no privacy policy URL.
- Recommended prices (README — suggestions §5).
- In-App Events at 860 × 560, and the event page’s narrow states.
- Help’s ? buttons in sections and error messages that link to an article.
- Analytics’ “own screenshots” fact is filled only in the sample data.
- Ask → toolbar from Product Pages and In-App Events.

## 5 · Not yet tried against Apple

These are built and tested here, but their writes have never reached App Store Connect, so their states may change after the first real try: Send Reply and the replies sent by themselves, a hand-made set’s deletes and new order, Submit, Release, Pause, event pushes and deep link edits, the China mainland availability change, a product page’s own screenshots and App Previews, Submit and Cancel for a product page.

## 6 · Recapture only some captures

**Built, no board yet.** When only some of an app’s texts change (Alba rewrote its Japanese phrases: 18 captures in ja on iPhone, iPhone Duo and iPad, plus one App Preview moment), redo only those captures, by hand or from Claude Code, without the whole Autopilot.

### By hand, in Screenshots → Captures

- Select one capture, a row (a language), a column (a screen) or several, in the coverage grid and in the viewer.
- **Replace…**: drop or choose a PNG for that capture, checked with the same size and matching rules as an import. No run opens.
- **Capture Again with Claude Code**: a run that only captures, with only those captures. It skips Plan and Design (the current plan, template and captions stay), keeps every other capture, Pick shows only the new ones, and Review & Push makes again only the images they change. It works for an App Preview moment too.

### From Claude Code

- `request_recapture`: the captures (screen, language, device, pose) or App Preview moments, why and the evidence. With no run open it waits as a request: a notice in Atlas, e.g. “Claude Code wants to capture 18 screenshots again in Japanese: phrases rewritten in d038b58”, with Accept and Decline. Accept opens the capture-only run.
- A new Settings switch, off by default: “Let Claude Code open capture-only runs”. On, a request opens the run without a click. Nothing reaches App Store Connect until the person pushes.
- `request_page_recapture` for a product page (up to 3 screens), without the person turning on Capture Screens Again first.
- It works with no saved Autopilot run too: the run is made from the captures the set uses (their screens, devices, iPhone Duo poses and sizes).
- `mark_captures_stale` and an **Out of date** tag on those captures in the grid; the captures list says when each was made, whether it is out of date and why.

To design: the selection in the grid and the viewer, Replace…, the request notice with Accept and Decline, the Settings switch, the Out of date tag, and Pick and Review & Push in a capture-only run.
