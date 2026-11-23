ATLAS · ACCEPTED · TOOLBAR · 21 NOVEMBER 2026

# The toolbar, Autopilot and Review & Push

Three things make the app harder to read than it should be: the toolbar is an empty band, Autopilot is in some sections and not others, and some pages have a second push button just under the one in the toolbar. This design gives each a single home. Nothing else in the sections changes.

**Accepted on 21 November 2026.** It is in the clickable app (*▶ App clicável*) and so in every board that draws the app. Build from this README.

**On the canvas.** *▶ App clicável* has it in the whole app: press Play, use the sidebar, open the Autopilot menu, accept a suggestion and click “N not pushed” under the title. Page *Toolbar e ações* has board 57 (every state of the toolbar), board 58 (reply to reviews automatically), a focused prototype with auto-reply, and this README.

## What was hard

- **An empty band on top.** The toolbar is opaque and holds only three buttons on the right. The section’s title sits again in the page, under it. On a 780 pt tall window that is about 120 pt before any content.
- **Autopilot isn’t one thing.** The same idea, “let Claude Code do this for me”, has five names in five places: Start Autopilot… (Screenshots header), Ask Claude Code… (Store Page, App Information), Make the Artwork… (an event), Suggest Pages and Make Screenshots for This Page… (Product Pages). Pricing, Reviews and Analytics have none, though Claude Code can help there too. You can’t learn where to look.
- **Two push buttons, 60 pt apart.** Push to App Store… (Screenshots), Review & Push… (Store Page, Overview, Analytics findings) and Push and Submit… (a product page) repeat the toolbar’s button in the page. It isn’t clear whether they do the same thing or push only that page.
- **“Assistant 42” doesn’t say what it does** or what the 42 counts, and it sits beside Review & Push with a count of its own.

## Three rules

### 1 · The toolbar is part of the page

- The page scrolls under the toolbar, with the soft edge of macOS 26. The toolbar has no background of its own.
- Leading: the section’s title (15 pt semibold) and one line under it with the section’s state, “32 suggestions in 6 languages · 3 not pushed”. The title row inside the page goes away; the page starts with its one-sentence description.
- A control that changes the whole page moves up beside the title: the language menu in Store Page and Screenshots, with its count. Accept All Languages stays in the page, next to the suggestions it accepts.
- Trailing, always in this order: **Autopilot** · Check now and History · **Review & Push**.

### 2 · One Autopilot button, same place, every section

- A split button with the sparkle icon. Its label is what Autopilot makes *here*, as a verb: Make Screenshots…, Suggest Texts…, Draft Replies…. Click runs it; the arrow opens everything Autopilot can do in this section, then **Everything for Lumen…** (Suggest Everything), then the Claude Code connection with Settings…. That last line replaces the Assistant button.
- The button is the run’s status. **Running:** it animates (see “While it works”) and says what it’s doing, “Making screenshots · 5 of 10 captures”; its menu has the progress bar and Cancel Run…. **Needs you:** purple, with what it needs, “Choose the Look”; a click opens that step. The menu bar icon and notifications say the same thing.
- A page may repeat an Autopilot action only in an empty slot (“Details image missing · Make the Artwork…”), with the same name and icon as the toolbar.
- Free plan: the button stays, with PRO on it; a click opens the paywall card for that action, as today.

### 3 · One Review & Push

- The toolbar button is the only way to push. No page has a Push or Review & Push button.
- Each section’s unpushed count is a link in the toolbar’s subtitle: **3 not pushed** opens Review & Push showing only that section, with chips to switch to All or another section. Pushing from there pushes only what’s shown: “Push 3 from Store Page…”.
- Accepting says where it went: the toast reads “Accepted. It’s waiting in Review & Push, top right.” with Undo, and the button bounces once.
- With nothing to push the button is plain glass and reads **Up to Date**; with changes it is blue with the count.
- Autopilot’s last step becomes **Approve All**: the parts join Review & Push and the sheet closes on it. The push itself, its progress and Retry Failed stay the one progress sheet that’s already built.
- A product page’s Push and Submit… becomes **Submit for Review…**. If the page has unpushed changes it opens Review & Push limited to the page first, as it already does. Submit for Review of the version stays in the sidebar footer: it sends a build to App Review, which is a different thing from pushing.

## While it works: the button’s animation

**Approved on 22 November 2026.** Build the animation as described here.

The button moves only while something is really running for this app: a suggestion request, an Autopilot run, drafting replies. Idle, it is still. Try it in the clickable app: Store Page → Suggest Texts….

| State | What you see | Timing |
| --- | --- | --- |
| Idle | Purple sparkle and the action’s name. No motion. | — |
| Working | A purple light travels along the button’s edge, left to right. The sparkle’s two stars shrink, turn and fade in turn. The label reads “Working · Store Page · German”, or the step, “Making screenshots · 5 of 10 captures”. | Edge 2.2 s per pass, linear, repeating. Each star 1.5 s, ease in-out, the small one half a cycle later. |
| Working, progress known | The same, plus a 2 pt bar inside the bottom of the button that fills as steps finish. | Bar eases to each new value in 0.7 s. No bar when the length isn’t known; never a made-up percentage. |
| Done | Green check that draws itself, “Done · Store Page · German”, and one small bounce. Then back to idle. The toast says what changed. | Bounce 0.45 s, check 0.35 s, shown for about 2 s. |
| Needs you | Solid purple with what it needs. Still: it waits, it isn’t working. | — |
| Failed | No motion; the label says what stopped, “Couldn’t reach Claude Code”, and a click opens the reason. | — |

- **Reduce Motion:** nothing moves. The edge becomes a steady purple outline, the small star stays dimmed, the bar still fills, the check appears at once.
- **VoiceOver:** the state is in the label, “Autopilot, working, Store Page German, 55 percent”. Start and finish are announced once; progress isn’t read out as it changes.
- The run belongs to the app, not the section: the button keeps animating when you move to another section, and the menu bar icon moves for the same runs.
- A run in another app doesn’t animate this window’s button; the app menu in the sidebar shows it.

## Section by section

| Section | Autopilot button | Also in its menu | Replaces | Toolbar subtitle |
| --- | --- | --- | --- | --- |
| Overview | Suggest Everything… | Make Screenshots…, Write What’s New for 1.4… | Review & Push… in the pipeline card | Lumen Journal · 1.4 not submitted |
| Store Page | Suggest Texts… | Suggest for English (U.S.) Only…, Translate into a New Language…, Ask Claude Code Something Else… | Ask Claude Code…, Review & Push… | 32 suggestions in 6 languages · 3 not pushed |
| Screenshots | Make Screenshots… (the guided Autopilot, board 21) | Make the App Preview…, Make Header and Search Artwork…, Capture Some Screens Again… | Start Autopilot…, Push to App Store… | 12 captions suggested · 40 not pushed |
| Product Pages | Suggest Pages… | Make Screenshots for a Page… (inside a page it becomes the button) | Suggest Pages, Ask Claude Code for Ideas, Push and Submit… | 3 pages · 2 ideas |
| In-App Events | Make Event Artwork… (inside an event: Make the Artwork…) | Write Event Texts…, Check It Will Pass App Review… | Make the Artwork… in the panel header, the event’s Ask | 3 events · 1 needs artwork |
| App Information | Suggest Answers… | Check Privacy Against the Code… | Ask Claude Code… | 7 answers suggested |
| Pricing | Suggest Prices… | Write a Retention Offer… | Accept All 3 stays; nothing removed | 3 suggestions · 2 not pushed |
| Reviews | Draft Replies… | Summarize What People Ask For… | nothing (new) | 4.7 ★ · 4 reviews without a reply |
| Analytics | Find What to Try… | Explain a Change… | Review & Push… on a finding | Last 30 days · 2 new findings |

Inside a sheet or a detail page (an event, a product page), the button’s label follows what’s open, and the menu keeps the section’s other actions.

## Sizes, keys and accessibility

- At 860 pt the Autopilot and Review & Push labels fold to their icons (the count stays), the title truncates, and the language menu goes to the toolbar’s overflow menu.
- `⌥⌘A` runs the Autopilot button’s action; `⇧⌘P` opens Review & Push. Both also live in the menu bar’s Product menu.
- VoiceOver: “Autopilot, Make Screenshots”, “Autopilot, making screenshots, 5 of 10 captures”, “Review and Push, 46 changes ready”. A change in the run’s state is announced politely, once.
- The soft edge keeps the toolbar readable over any content; with Reduce Transparency the toolbar gets the window’s color.

## Reply to reviews automatically (Pro) · board 58

New reviews get a reply written in their own language, and the ones you allow go out by themselves. Everything else is drafted and waits for you. Free keeps writing replies, or asking for a suggested one, one review at a time; this follows the plan’s rule, since Pro is the part that runs without you.

### What Apple allows, and what it changes

- **No push for reviews.** App Store Connect’s webhooks cover version states, builds, TestFlight feedback and a few others, not customer reviews. Atlas checks each app’s reviews on the hourly check it already runs from the menu bar, so “automatic” means within about an hour, while Atlas is running. A Mac that was asleep catches up when it wakes.
- **The reply is public, under the review.** It uses the same write as Send Reply. Send Reply hasn’t reached App Store Connect yet (README — built, §5), so it has to be tried by hand before anything is sent automatically.
- **App Review’s rules for replies apply.** Respond to what the person wrote, with no marketing, prices, other platforms or personal information. Atlas already warns about these for replies; for an automatic reply they block the send, and the reply waits for you.
- **Who writes it.** The person’s own assistant, as everywhere in Atlas. With Claude Code, Atlas starts it for the reply (board 22); with an API key it calls it directly. If neither is available, the review waits with “Couldn’t write a reply: Claude Code isn’t connected”.

### The flow

1. **Start:** Reviews’ Autopilot menu → **Reply Automatically…** (board 58 · 1).
2. **Settings** (· 2): *Draft a reply and tell me* (nothing sent until you press Send) or *Send the ones I allow by themselves*; the ratings that may go out alone (4★ and 5★ by default); the languages; topics that always wait for you (a bug or crash, billing or refund, their account or data, a feature request, something personal), read by Claude in any language, plus any review it isn’t sure about; a wait before sending (15 min, **1 hour**, 3 hours); at most 10 a day; tone (Warm, Brief, Formal) and a signature; an example reply that changes with the tone.
3. **On** (· 3): the Autopilot button reads “Auto-reply on · 2 sent today” with a green dot, the subtitle says “auto-reply on”, and a strip at the top of Reviews has the rule, the next check, Pause and Settings…. A reply in its wait shows “Sends by itself in 42 min” with Send Now, Edit… and Don’t Send.
4. **Needs you** (· 4): a notification (“A 1★ review needs your reply”, with the review and why) with Open Reply and Later; the Autopilot button turns purple, “1 Review Needs You”; the draft waits under the review with Send and Edit….
5. **History** (· 5): every automatic reply with Undo. Undo deletes the reply on the App Store and keeps the draft.
6. **Paused** (· 6): from the strip, the Autopilot menu or the menu bar. New reviews are drafted and wait.
7. **Free** (· 7): the settings open and show what it does, with Upgrade…; Turn On waits for Pro.

Replies never mention prices, offers, other apps or dates for new features, and never ask for a better rating. A reply that would break one of these isn’t sent: it waits, with the reason.

## In the clickable app

- Every section: title and status in the toolbar, the in-page title row removed, the Autopilot button with its menu, “N not pushed” opening Review & Push for that section only, and Up to Date when there is nothing to push.
- Autopilot actions run the flows that already exist: the request travels to the button and the button animates and shows “Working · …” with its progress while Claude Code works, then “Done · …”. Make Screenshots… opens the guided Autopilot (board 21); Make the Artwork… opens the event’s artwork flow (board 47).
- Removed from the pages: Ask Claude Code… (Store Page, In-App Events), Start Autopilot… (Screenshots), Suggest Pages (Product Pages header; the empty list keeps it as Suggest Pages…), Review & Push… (Overview, Analytics findings). Push and Submit… is now Submit for Review….
- Not in the clickable app: the page scrolling under the toolbar (the boards keep a plain toolbar row; build it as described below), and auto-reply, which is in the focused prototype on *Toolbar e ações*.

## For Claude Code

- **Title.** Keep `.navigationTitle(section.title)` for the window menu and Mission Control, hide the system title with `.toolbar(removing: .title)`, and draw title and subtitle as a `ToolbarItem(placement: .navigation)`, so “3 not pushed” can be a button. The language menu is a second item in the same placement.
- **Content under the toolbar.** Remove any opaque toolbar background (`.toolbarBackground(.visible)` or a colored view behind it). Scroll views go to the top of the window and add `.scrollEdgeEffectStyle(.soft, for: .top)`. Don’t put `.ignoresSafeArea()` on interactive content; the scroll view already insets it.
- **Autopilot.** One `AutopilotButton` in `ToolbarItem(placement: .primaryAction)`, driven by the section: each section provides `autopilotActions: [AutopilotAction]` (title, icon, run, isPro), first one primary. `Menu { actions… } label: { Label(primary.title, systemImage: "sparkles") } primaryAction: { run(primary) }` gives the split button. Running and Needs-you come from the run engine the menu bar icon already reads. Needs-you uses `.buttonStyle(.glassProminent).tint(.purple)`.
- **The working animation.** Drive it from one `AutopilotRunState` (idle, working(step, progress?), needsYou, done, failed) published by the run engine. Sparkle: `Image(systemName: "sparkles").symbolEffect(.variableColor.iterative, options: .repeat(.continuous), isActive: isWorking)`, or `.breathe` if it reads better on the glass. Edge light: a `Capsule().strokeBorder` overlay with a gradient whose start point animates across (`phaseAnimator` or a repeating linear animation), 1.5 pt, only while working. Progress: a 2 pt `ProgressView(value:)` styled as a bar at the bottom, only when the engine reports a fraction. Done: `.contentTransition(.symbolEffect(.replace))` to `checkmark.circle`, green tint, for 2 s. Respect `accessibilityReduceMotion` as described above. Check the exact symbol effects against the macOS 26 SDK when building.
- **Review & Push.** `ReviewPushSheet(scope: .all | .section(id) | .productPage(id))`; chips switch scope; the push button pushes only the scope. `.glassProminent` when there is something to push, `.glass` and “Up to Date” when not.
- **Remove from pages:** Start Autopilot…, Push to App Store… (Screenshots), Ask Claude Code… in section headers, Review & Push… in Overview’s pipeline card and on Analytics findings, Push and Submit… on product pages (becomes Submit for Review…), the in-page section title row, and the Assistant toolbar button (its popover’s connection and setup move to the bottom of the Autopilot menu).
- The engine, MCP tools and what each action does don’t change. This is where the actions live and what they’re called.
- **Auto-reply.** A per-app `AutoReplyRule` (mode, ratings, languages, waitTopics, delay, dailyCap, tone, signature), off by default, behind `Entitlements.canUse(.autoReply)`. On each hourly check, new reviews without a response get a draft; a draft that matches the rule, passes the reply rules and isn’t flagged for a topic is queued with a send time; everything else is marked Needs You and notified. The queue survives a quit and a sleep; nothing older than 7 days is sent automatically. Undo deletes the customer review response. Every automatic send is written to History with the rule that allowed it.
- For assistants, MCP tools to list reviews that need a reply and to propose a draft for one. An assistant never turns auto-reply on, changes its rule or sends a reply itself.

To validate: what the Assistant button’s count is in the app today (if it counts requests waiting for the person, they become the Autopilot button’s Needs-you state); whether Approve All at the end of Autopilot is one click too many for people who always push right away; whether Reviews and Analytics need their Autopilot actions in the first version or can show the button with only Everything for Lumen….
