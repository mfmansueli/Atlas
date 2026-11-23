ATLAS · SCREENSHOTS · PREVIEW AND AUTOPILOT · NOVEMBER 2026

# Screenshot Studio: the preview first, and Autopilot

**Autopilot is the guided flow** described in **README — Autopilot** (board 21): What to make → Look → Plan, then it runs on its own and stops only to Choose the look and to Review & push. Sections 3 to 9 below still describe how it works underneath (capture, Claude Design, This Mac, iPhone Duo, header and App Preview). Where they mention the earlier sheet’s screens, the current flow puts them here: *stages on the left* → the stepper at the top; *What this run makes* → step 1; *Header style, Screenshot style, music* → step 2 · Look; *screens, Add a Screen, This Mac, Simulator* → step 3 · Plan; *Pick captures* → off by default, an option in the plan; *Choose a direction* → step 5; *Watch the App Preview / the header loop, Ready for review* → step 6, one tab per part. The earlier sheet’s boards were removed from the canvas on November 18.

Screenshots becomes its own section (⌘4), led by what people actually see: the App Store product page and search result, at real proportions, in each language and device. Above it, Autopilot runs the whole job. Your assistant runs the app in Simulator and captures the best real screens. Your design project designs the set in your brand. Atlas localizes and checks every screenshot, and keeps every step, version and decision in one place.

**On the canvas.** *Prototype — screenshot studio* sits below the prototypes row; press Play, then Start… on the Autopilot card; its Prototype pill restarts the Autopilot flow or jumps to Review & push. Board 21 shows every step. The sets matrix, template editor, captions, proposals and Review & Push stay as in *Prototype — localized screenshots*, reached from **Sets, Template and Captions**.

## 1 · The section

- The toolbar gains **Screenshots** between Store Page and App Information (Subscription Pricing shortens to **Pricing** to make room). Store Page keeps the text fields.
- Header controls: device (*iPhone 6.9″ · iPad 13″*), language, and **Live · New**. *New* is available while a new set waits in Review & Push.
- **App Store preview** is the largest thing on the page: icon, name, subtitle, ratings line and Get button in that language, then the five screenshots at real proportions, scrolling like the store. Right-to-left languages run right to left. A Light/Dark switch shows the store in either appearance, independent of the app’s.
- Under each screenshot: its slot and a chip when something is worth knowing: *English* (this language falls back today), *New*, *Shortened* (a caption was changed to fit).
- **In search results**: the first three screenshots at search size, where most of the decision happens. **Live set / New set**: how it was made, languages covered, iPad, checks.

## 2 · Autopilot

| Step | Who | What happens |
| --- | --- | --- |
| **1 What to make** | You | Screenshots (devices), App Preview (English only or every language), header and search artwork (still or moving), and the languages. A sentence says exactly what you’ll get. |
| **2 Look** | You | Screenshots: a new look from Claude Design, start from templates (previewed with the real engine on every device and language), or keep the current one. Header scenes or Claude Design’s own concepts. Music. One note for the designer. |
| **3 Plan** | You | Who does what and how long, with the two stops marked. Screens, This Mac (simulators ready), Simulator options and Pick captures fold in here. |
| **4 Making it** | Claude Code, Claude Design, Atlas | Capture in Simulator, design, localize and check. One progress bar; hide it and the Screenshots card shows progress. |
| **5 Choose** | You | Screenshot looks and headers side by side, Claude’s pick marked, Ask for Changes on each. Can be skipped with “Choose the look for me”. |
| **6 Review & push** | You | One tab per part, every device in the run, every language, with its checks. Approve each part; nothing is uploaded until you push. |

- MCP is driven by the client, so the run starts with one prompt pasted into Claude Code (or `/mcp__atlas__run_screenshots`). After that, Claude Code asks Atlas what to do next, step by step.
- Every capture, pick, look and template version is kept. Running again only redoes what changed: a new screen, a new language, a new look.

### Every device the app ships on

The plan used to offer iPhone and iPad only. It now reads the targets in the Xcode project and the platforms on App Store Connect, and offers every device the app needs screenshots for. Lumen 1.4 has a watch app and adds visionOS, so the plan shows:

| Device | Size | Why it’s in the plan | Screens |
| --- | --- | --- | --- |
| iPhone 6.9″ | 1320 × 2868 | Required for every iPhone app | 5, with captions |
| iPad 13″ | 2752 × 2064 | Lumen runs on iPad | 5, same moments as iPhone |
| Apple Watch Ultra 3 | 422 × 514 | Lumen has a watch app, LumenWatch | 4: Mood, Today’s prompt, Week, a watch face with the complication. No captions: the App Store shows watch screenshots bare |
| Apple Vision Pro | 3840 × 2160 | 1.4 adds visionOS | 3 windows, framed in the chosen direction with captions |

- A device can be turned off; the row then says it has to be uploaded by hand before submitting. iPhone can’t be turned off.
- Apple Watch captures run on a watch simulator paired with the iPhone simulator, in every language. The pick step shows the watch picks in their own row.
- The preview’s device control lists every device; a device with nothing live (Apple Vision Pro here) says it’s required before submitting and offers Autopilot.
- **Languages** work the same way: the plan includes the 3 languages in `Localizable.xcstrings` that aren’t on the App Store yet (Polish, Turkish, Hebrew), for 15 in all; Store Page suggests creating their pages. 17 screens per language × 15 = 255 captures.

## 3 · Capture: real screenshots from the running app

Capturing needs an assistant that can run Xcode on this Mac: Claude Code, Codex or Cursor. Without one, the strip says so and offers **Import Captures…**; design and localizing still work.

- **The plan** is written by the assistant from the code: XCUITest screenshot tests when they exist, otherwise deep links or launch arguments it finds. Each screen has a name, the steps to reach it and the caption it goes with. You can edit any of it.
- **Simulator setup** uses Xcode’s own tools: `xcrun simctl status_bar … override` for 9:41 and full bars, `simctl privacy … grant` for permissions, appearance, and the app’s sample-data switch. Languages come from `-AppleLanguages` and `-AppleLocale` at launch.
- **Ranking.** The assistant captures each screen up to three times and scores them: content filled in, no keyboard, alert or spinner, nothing private on screen, matches the caption. You see the reasons.
- **Problems** don’t stop the run. The failing screen shows what happened, the fix the assistant proposes (for the photo picker, granting access first), and two ways out: use the English capture, or upload one by hand. The fix is added to the plan.

```
get_capture_plan(app, version)          → screens, steps, devices (from targets and platforms), locales (App Store + app), simulator setup
report_capture(app, run, screen, device, locale, file, attempt, score, notes)
report_capture_problem(app, run, screen, device, locale, what, proposed_fix)
next_step(app, run)                     → what Atlas wants next: capture, wait for the person, shorten a caption, done
```

## 4 · Design: your design project, not ours

| Source | What it reads | Where you refine |
| --- | --- | --- |
| **Claude Design** · recommended | A design system or project: colors, type, logo, components, voice | In Claude Design (**Open in Claude Design**), and in Atlas’s template editor |
| **Figma file** | Color and text styles, the logo, frames named “Screenshot/…” | Template editor; nothing is written to Figma |
| **Brand folder** | tokens.json, fonts, an SVG logo | Template editor |
| **No design project** | The three starters, colored from the app icon | Template editor |

- **The brief** Atlas gives the design AI: the five picks, every caption in every language with its length, canvas sizes for each device, safe areas, the longest caption per slot, and that right-to-left languages mirror.
- **What comes back** is a template in Atlas’s format (the contract in the screenshots README). That keeps the result renderable in 12 languages and editable here, instead of 120 flat images.
- **How Claude Design is reached**: through Claude, which can open the design project and talk to Atlas over MCP. Whether that’s the same assistant that captures, or a Claude session with access to Claude Design, depends on what each one can reach. Connect stores the link and shows what was found, so you can see it’s the right system.

```
get_design_brief(app, run)              → picks, captions, sizes, safe areas, longest captions, brand source
propose_direction(app, run, name, rationale, template, source_link?)
                                        → queued | refused (with the template check that failed)
revise_direction(app, run, direction, note)   // from “Ask for changes”
```

## 5 · Decisions

- **Screenshots gets its own section.** It’s the most visual part of the listing, and it was hidden under Store Page.
- **The preview leads, the tools follow.** The question is always “what will people see?”; the matrix and editor stay one click away.
- **Templates, not images, from the design AI.** One design renders correctly in every language and device, and Atlas can check it.
- **Two checkpoints by default**, both optional: picking captures and choosing a direction. Review & Push always asks.
- **Real captures only.** The design AI never draws the interface; it designs around what the app really shows.

## 6 · Built since: Autopilot on a real Mac

What the app does today that the boards above didn’t show. Boards 24 (iPhone Duo, This Mac, the sidebar) and 25 (a run that keeps going) draw it.

### iPhone Duo, required by Apple

- iPhone Duo is the third rendered set, beside iPhone and iPad: same slots and captions, at its inner display, **2007 × 2853**. Apple requires it from April 2027 for apps built with the iOS 27.1 SDK.
- It’s in **every plan**. Turning it off says its screenshots are left to upload by hand. The device menu lists it under **Required by Apple** (*2007 × 2853 px · from April 2027*); a set with nothing yet says *None yet: required from April 2027*.
- The Duo’s inner display captures **landscape, 2853 × 2007**. A template with no canvas of its own for the Duo follows each capture’s orientation, so nothing is cropped.

### This Mac, before Start

- The plan checks each planned device for a simulator: ready (*iPhone 17 Pro Max · iOS 27.0*), **Make the Simulator** when the runtime is there, or **Install the iOS Simulator** (`xcodebuild -downloadPlatform`, several GB) when it isn’t. **Check Again** sits on the group.
- The check runs through the helper. Without it: **Install Helper…**; with an older one: **Save the Helper Again…**, saying what the new one adds.
- A device-wide problem found while capturing (no simulator for it) gets **Install** or **Leave iPhone Duo Out** on its card, instead of one card per screen.

### iPhone Duo opens itself

- The Duo simulator starts closed and only its cover display shows the app. Atlas opens it when the run needs it: it opens the device’s window in Device Hub and presses **Open**. That needs Accessibility once (**Open Accessibility Settings**); **Open Now** does it before Start.
- While the run goes on it watches the inner display. Stuck on a spinner for 90 s, or with a crashed SpringBoard, it restarts the Duo itself, twice at most, then asks to erase it in Device Hub.
- The UI test’s own screenshot only sees the cover, so Atlas records the inner display while the test runs and keeps the frame taken when each screenshot was attached.

### Fewer, clearer problems

- **Rehearsal.** Every screen runs first in the primary language and in one with another script (Arabic here), so what breaks in every language shows up once. A problem holds that screen on that device in the other languages until it’s fixed.
- **One card per cause.** The same cause on many languages and devices is one card. A fix that is a command is retried; a fix that needs a change in the project says what to change, and **Use the Primary Capture** settles the other languages.
- **Refused commands.** Atlas’s Claude Code may only run `xcodebuild`, `xcrun` and the like; a command it was refused (e.g. `VAR=1 xcodebuild …`) is shown, with the change that avoids it (a scheme that sets the variable, `-testLanguage`).
- **Text check.** Atlas reads the text in every capture: mostly in the wrong language, cut-off text, a system prompt showing. Those rank below clean attempts, and Pick lists *N captures to check*. The plan adds **Sample data in each language**.

### It keeps going, and only real failures look like failures

- When Claude Code ends with work left, Atlas starts it again. When it stops because it’s your turn (pick, choose), that’s not an error: your answer continues the run.
- If Atlas was quit mid-run, the run is **Paused**, not red. A quiet run gets a notice with what Claude Code last said and **Continue** (or **Copy the Prompt to Continue** without the helper).
- Design shows who is working, the step and elapsed time, *N of 3* directions, and only the next direction spins, only while someone works on it.
- Atlas’s own Claude Code only reaches Atlas’s MCP, so it can’t open Claude Design or Figma: it designs from the brief, which carries the design project’s saved summary.

```
get_capture_plan(app, run)              → … + preflight checks, rehearsal locale, test arguments per language
report_capture(…)                       → check (the text found) and next
report_capture_problem(…, refusedCommand?, changesProject?, affectsDevice?)
start_display_recording(app, run, displayType: iphone_duo)
finish_display_recording(app, run, resultBundle)
                                        // iPhone Duo’s inner display, frame picked by attachment time
```

### Library and push

- The sidebar shows the team’s name, read from its certificates (App Store Connect has no team endpoint), and each app’s icon from its latest build. An app with no processed build keeps its letter.
- A new language whose page already exists in App Store Connect is updated instead of failing as a duplicate.
- An empty screenshot set left by an unfinished upload is filled, not created again. A live screenshot with no image is replaced without a backup, and the row says so.
- Upload progress counts bytes, so the bar moves while each large screenshot uploads.

## 7 · Also make: header, search results and App Preview (optional)

Two optional extras in the plan, under **Also make · optional**. Both are off by default, are made by the same design source as the screenshots (Claude Design here, or the starters), are checked by Atlas, and wait in Review & Push like everything else. Board 26 shows them.

### What this run makes

The plan starts with a card that says what this run makes, so a run can be as small as one thing. Board 27 shows it.

- **Presets:** Everything · Screenshots (default) · Header and search · App Preview · Custom. Changing anything below switches to Custom.
- **Rows and devices:** Screenshots per device (iPhone, iPad, Apple Watch, Apple Vision Pro); App Preview per device (iPhone, iPad; others show “—”); Header and search with its size choice (21:9 + 3:2, or one 16:9). A row that’s off says what stays: “the live screenshots stay as they are”.
- **Languages:** All (with or without the languages not on the App Store yet) · English (U.S.) only · Choose…, which shows a chip per language. The App Preview row keeps its own choice: English (U.S.) only, or the run’s languages.
- **Captures:** capture in Simulator, or reuse the last captures and picks (build and date shown). Reusing is faster but shows the app as it was. Apple Watch and Apple Vision Pro without earlier captures are captured anyway; the App Preview is always recorded. Disabled when nothing in the run needs captures.
- **The stages follow the choice:** Capture and Pick show “Skipped · reuses the Oct 28 captures” when nothing is captured; the plan table lists only what is captured or recorded; Localize and check lists only the run’s languages and assets; Ready and the preview describe exactly what was made, and the parts not in the run stay live.
- A summary under the card says what will be made and that “Everything else on the App Store stays as it is”. With nothing selected, Start Autopilot is disabled.

### Adding screens to the plan

Under the plan’s screens (and in its collapsed summary) there are two ways to add one. Board 28 shows them.

- **+ Add a Screen…** opens a short form: name, how to get there (Claude Code’s steps), and the English caption. “Let Claude Code work out the steps and add them to LumenUITests” is on by default, so a name is enough. An empty caption is written by Claude Code.
- **Suggest Screens** asks Claude Code, optionally with a request (“one that shows the streak”). It reads the UI tests, the commits since the last version and the live screenshots, and suggests screens the set is missing, each with why, the steps and a caption. **Add to Plan** or **Dismiss**; nothing is added on its own.
- New screens go after the existing ones on iPhone and iPad, are marked “Added by you” or “Suggested by Claude Code”, can be removed, and count in the run’s total. They’re captured even when the run reuses earlier captures. Their captions are translated in Localize and check.
- Apple allows up to 10 screenshots per device; at 10 both buttons are disabled with that reason.

```
suggest_screens(app, run, request?) → [ { name, reason, evidence, steps, caption } ]   // Claude Code; shown, never added automatically
add_screen(app, run, name, steps? | "auto", caption?)                                  // "auto": Claude Code writes the steps and the UI test
```

### Product page header and search results artwork

| Choice | What is made, per language | Apple’s size |
| --- | --- | --- |
| **Header 21:9 and search 3:2** (default) | Two images: a wide header for the top of the product page and a search results image | Header 3840 × 1646 (.png or .jpg). Search results 3:2, 1920 × 1280 up to 3840 × 2560; Atlas makes 3840 × 2560 |
| **One 16:9 image for both** | One image used in both places | 5244 × 2950 (.png) |

- The design source gets the same brief as the screenshots plus these canvases and the artwork brief below, and returns them as templates, so each language gets its own words and right-to-left languages mirror.
- Real captures only, as in the screenshots: the phones in the artwork are Claude Code’s picks. No alpha channel, as Apple requires.
- In the preview, the header sits on top of the product page and the search card shows the artwork, with a note that search falls back to the first screenshots where Apple doesn’t show artwork.

### Still image or motion loop

With header and search on, the plan card has a **Header and search** row (board 32): **Still image** (default) or **Motion loop**.

| Choice | What is made, per language | Apple’s spec |
| --- | --- | --- |
| **Still image** | Header and search images | .png or .jpg, no transparency. 21:9 3840 × 1646; 3:2 up to 3840 × 2560 (or one 16:9 5244 × 2950 .png) |
| **Motion loop** | A 20-second silent loop for each place, with its first frame as the poster | .mov, .m4v or .mp4; 30 or 60 fps; 5–30 s. Only at 21:9 (3840 × 1646) and 3:2 (up to 3840 × 2560); loops continuously; muted by default (search results can’t be unmuted) |

- Apple takes no 16:9 video, so **Motion loop** switches the sizes to 21:9 and 3:2, and choosing **One 16:9 image for both** switches back to Still.
- Claude Design animates the direction it designed; Atlas encodes, checks the length, frame rate and that the last frame matches the first, and renders each language. The preview plays the loop in place with a *0:20 loop* chip; the full-size viewer says “plays muted on repeat”.
- The full-size viewer’s **Show iPhone Area** dims what an iPhone doesn’t show of the 21:9 header and the band under the status bar, Back and Share. The exact safe area comes from Apple’s header template; the one drawn here is an estimate.

### What the artwork shows, and the expected result

Under Still/Motion, the same row has a second choice for the search artwork (the header never shows a device):

| Choice | What Claude Design makes | Captures |
| --- | --- | --- |
| **A phone with the app** (default) | One real screen from the captures, in a phone (or a hand holding one) | Needed |
| **The app, no device** | The same real screen, cropped, rounded and floating, with no phone frame | Needed |
| **No app: a scene** | Only the name, the headline and a scene in the brand’s style. Apple advises showing the app in search, so the note says when this fits: when the app’s look says more than its screens. | Not needed for the artwork; an artwork-only run skips capture |

- **Expected result** (collapsed by default, “Describe the Result…”): a free-text description, quick additions (Night sky with the moon, Hand holding the phone, Bigger headline, Warmer colors, Winter season) and **Add Image or Video…** for references. Claude Design takes the feel from the references, not the content.
- The description and references are sent with the brief and listed in it as “Your direction”. After the directions arrive, “Ask for changes” on a direction still works as before.

```
get_design_brief(app, run) → … extras: { art_show: "phone" | "ui" | "scene", art_direction: { text, references: [file] } }
```

### Header style: templates or go freely

Inside the Header and search row, **Header style** decides where the concepts come from (board 33).

- **Start from templates** (default): six scene templates, each previewed in the app’s colors with its name (and, with Motion loop, animated). Pick up to 3; a 4th replaces the last. Claude Code recommends one from the scan, with a reason (Lumen: Day to Night). Claude Design adapts each picked template to the app: it keeps the scene type and the loop and chooses the subject, colors and details.
- **Go freely**: Claude Design proposes 3 concepts of its own, each a different metaphor from the app’s world. The plan shows exactly what it gets from the scan: what the app does, its look (icon, colors, fonts), the screens, the brand and the user’s direction.

| Template | Scene | Loop | Fits |
| --- | --- | --- | --- |
| **Day to Night** | Open sky over a low horizon, sun or moon, stars | Sun sets, moon rises, stars come out, dawn returns | Sleep, journaling, weather, calm |
| **Layered Landscape** | 3–5 receding layers of hills, forest, mountains or dunes | Layers drift at different speeds while the light changes | Outdoor, health, travel, wellness |
| **Window View** | A strong frame (airplane window, porthole, room window) with the outside behind | The sky behind the frame goes day, dusk, night, dawn | Travel, home, productivity |
| **Horizon** | Water or a skyline at two-thirds height, with something passing | A boat, train or lights cross; light moves on the water | Games, travel, maps, sport |
| **Hero Object** | One large object tied to the icon, low-contrast behind the name | A soft light sweeps across it | Utilities, finance, tools |
| **Brand Pattern** | Abstract shapes from the icon’s geometry | Shapes drift and overlap | Apps with no physical metaphor |

### What the user sees and approves

1. **Design**: a line says what comes next (“Next, you choose 1 of 3 screenshot directions and 1 of 3 headers…”). The header concepts appear as they are designed: a still, the name, where it came from (template or Claude Design’s own), the metaphor, why it fits and, with motion, the loop.
2. **Choose a direction and a header**: the header and search are chosen apart from the screenshot direction, so any pair works. Each concept opens full size. **Use These** waits for both choices. In an art-only run the step is **Choose a header**. Unattended runs take the recommendation and say so.
3. **Watch the header loop** (with Motion loop): the loop made from the chosen header, header and search, with quick asks (Slower movement, Warmer light, Fewer stars, Bigger name) or free text; each request returns v2, v3… **Approve Header Loop**, or **Approve Both** when there is an App Preview too.

**How this fits what is built (section 8).** Each concept is made of Claude Design’s own pages, with the same data-al marks: the name is each language’s App Store name, and phrases are written once and translated in Captions. The change is that concepts are proposed apart from the screenshot directions (`propose_artwork_concept`), so the header can be chosen on its own, and motion is a second pass on the chosen pages, approved in Watch the header loop. The prompts for this are in *Atlas-header-prompts.md* (v3).

### Screenshot style

For screenshots, a **Screenshot style** row offers **Claude Design proposes 3** (default), **From templates** (up to 3 of the 12 templates; one direction from each) or **Keep template v4** (only captures and captions change; nothing to choose).

```
get_design_brief(app, run) → … extras: { art_style: "templates" | "free", art_templates: ["night", "land", "window"], shot_style: "free" | "templates" | "keep", shot_templates: [name] }
```

### The artwork brief Claude Design gets

Shown in the Design step (“What Atlas asks Claude Design for the header and search artwork”), and sent with `get_design_brief`. Drawn from Apple’s *App Store asset best practices* and from the reference loops shared for this design (three apps’ headers and search cards, about 28 s each).

| Rule | What it says |
| --- | --- |
| **Header · 21:9** | Brand first, for a first-time visitor: the app name (icon and wordmark) and one short line, centered, over a scene in the brand’s colors. No phones and no small text. On iPhone only the middle of the image shows and the top sits under the status bar, Back and Share, so nothing important goes on the sides or the top. |
| **Search results · 3:2** | State the obvious: a headline of 2 to 5 words on one side, one real screen from the captures on the other (a phone, or a hand holding one). The whole image shows, small, under the app name and Get. |
| **One look for both** | Same colors, scene and type in both, so people recognize the app from search to the product page. One clear focal point; nothing dense. |
| **Motion** | Slow, ambient movement only: light and sky shifting (day to dusk to night and back), clouds or hills drifting, the phone floating a little. No cuts, no fast moves. The app name and headline never move and stay readable. |
| **Poster, loop, sound** | The first frame is the poster and works as a still. The last frame matches the first, so the loop doesn’t jump. Silent; it must work muted. |
| **Words** | Written in each run language, not translated word by word. No prices, discounts, awards, website addresses, other platforms or Apple badges. Readable at the smallest size. Suitable for 4+. |

### Pick captures: screenshots and the App Preview recording

When the run makes both, Pick captures has two tabs (board 31).

- **Screenshots.** For each screen, Claude Code’s pick is shown large with its reason, and below it the 3 attempts it ranked (for example, keyboard covering the prompt, a permission alert, an empty list). Click any capture to open it full size; the viewer steps through the attempts and has **Use This Capture**. Your picks are marked “Your pick”. Device switch: iPhone and iPad, iPhone Duo (inner and cover as chosen in the plan) and Apple Watch. New screens added in the plan show up as their own cards.
- **App Preview recording.** The raw take Claude Code recorded (no captions or music yet) plays in place: Play/Pause, time, and a bar where the marked moments are blue. Switch device and, when every language gets a preview, language. **View Larger** opens it in the full-size viewer.
- **Moments.** Claude Code marks the moments that work in an App Preview, each with a reason. Check which go in, play one, or ask for **Record Again**. The total (moments plus the end card) must stay within Apple’s 15–30 s; outside it, the button waits. The Watch the App Preview step later plays the result built from these moments.
- If no recording was made yet (an earlier run, or a run without an App Preview), the tab doesn’t appear.

```
list_recording_moments(app, run, device, locale) → [{ id, screen, start_s, end_s, reason }]   // Claude Code
rerecord_moment(app, run, moment_id)                                                        // Claude Code, before Design
```

### App Preview video

| Choice | What is made | On the App Store |
| --- | --- | --- |
| **English (U.S.) only** (default) | One preview per device, from the English recording | Languages without their own preview show the English one. The preview’s chip says *English* in those languages. |
| **Every language** | One preview per device and language, from each language’s recording, captions translated | Each language has its own |

- **Who does what.** Claude Code records the plan’s screens in the Simulator (`xcrun simctl io booted recordVideo`) in the same run as the captures. The design source styles the captions, the end card and the poster frame. Atlas cuts, captions and encodes it, and checks it against Apple’s rules.
- **Apple’s rules it checks:** 15–30 s; up to 3 previews per device size and language; H.264 or ProRes 422 HQ, at most 30 fps and 500 MB; stereo audio; iPhone 6.9″ 886 × 1920; poster frame (default 0:05). The iPad size in the plan, 1200 × 1600, is an assumption to check on Apple’s specifications page.
- **Only the app itself** on screen, as Apple requires for App Previews: recorded in the app, no device frames or hands; captions and the end card frame it.
- The plan’s time estimate grows by about 2 min of recording for English only, or about 12 min for every language, plus design time.

### iPhone Duo: inner display, cover display or both

When the run makes iPhone Duo screenshots, the plan card has an **iPhone Duo** row (board 30):

- **Inner display** (default): unfolded, at Apple’s 2007 × 2853. Atlas opens the Duo in Device Hub for each capture, as in section 6.
- **Cover display**: folded, with the app on the cover screen, placed on the 2007 × 2853 canvas. Faster (the Duo never opens), but the big screen isn’t shown.
- **Both**, with a second choice: **Side by side in each screenshot** (the unfolded Duo with the folded cover beside it, one image per screen, same count) or **As separate screenshots** (inner then cover for each screen; capped at Apple’s 10 per device, so with more than 5 screens only the first 5 get a cover one).
- The plan table, capture log, totals, preview (Duo tab) and full-size viewer follow the choice. Claude Code’s steps are the same screens as iPhone; for the cover it keeps the Duo folded.

Assumption to check: which states Apple accepts for iPhone Duo screenshots. The design keeps every image at the required 2007 × 2853, so a cover-only set is framed inside it; if Apple asks for the inner display only, “Cover display” should be limited to sets that also include inner screenshots.

### Music (required) and the “Watch the App Preview” step

- **Music is required.** When the run makes an App Preview, the plan shows a Music row with no “None”: Warm acoustic (default), Calm piano, Bright pop, or **Your File…**. Library tracks are licensed for the App Store; with your own file you confirm you hold the rights. Atlas mixes it under the captions in stereo (Apple requires stereo audio) and fades it out at the end.
- **A new checkpoint, “Watch the App Preview”**, sits between Localize and check and Review & Push (on by default; “Stop for me to watch the App Preview” in Design and checkpoints). It plays the preview: click the video or Play, a timeline per scene (click to jump), Sound On/Off, the music track, and a language switch when every language has its own preview.
- **Ask Claude Design for changes:** quick asks (Slower pace, Start with Search, Bigger captions, Calmer music) or your own words. Claude Design returns a new version (v2, v3…) listed with what changed. Only captions, pacing, order and the end card change; the recordings stay. Changing the music doesn’t need Claude Design: it’s mixed again at once.
- **Approve App Preview** moves the run to Review & Push.

```
revise_app_preview(app, run, request) → { version, changes }   // Claude Design; captions, pacing, order, end card
set_app_preview_music(app, run, track_id | file)                // no design step; Atlas re-mixes
```

### Full-size viewer

Click any screenshot, header or search artwork, direction thumbnail or App Preview to see it full size over the app, with its name, size and language, previous and next, and Esc or ✕ to close. The App Preview plays in the same viewer. On the Mac this is a Quick Look–style panel: Space opens it, the arrow keys move.

```
get_design_brief(app, run)  → … , extras: { header: "21:9" | "16:9", search: "3:2" | "16:9", art_motion: "still" | "loop", art_brief: [rules], app_preview: { languages: "primary" | "all", length_s: 24 } }
propose_direction(app, run, name, rationale, template, extras_templates?)   // header, search and preview styling in the same direction
report_recording(app, run, device, locale, file, duration_s)               // Claude Code’s Simulator recordings for the App Preview
```

## 8 · Built since: Claude Design’s own pages, every language, Review & Push

What the app does today that boards 26–32 didn’t show. Boards 34 (Claude Design’s header and search pages), 35 (header or search only, names and phrases per language, Apple Watch screens, Cancel Run) and 36 (Review & Push) draw it. Board 33 (Header style) is newer than this and isn’t built yet.

### Header and search are Claude Design’s own pages

- Claude Design makes every design decision for the header and search: it sends one HTML page per place, and Atlas renders it in each language, checks it and turns it into the PNG or the 20-second loop. The built-in layout made every direction look alike, and “Ask for changes” could only change colors.
- The page marks what Atlas fills in: `data-al="appName"` (the App Store name in that language), `data-al="text"` (the page’s own phrases) and the capture it shows. Its own CSS animates it; the loop is recorded from the page, and its first frame is the poster.
- **What you asked for comes first.** The Expected result leads the brief and outranks Apple’s role advice, and each direction has to say how it follows it, or it’s refused.
- A run that makes only header and search shows no screenshot template on Design and Choose: each direction is its header and search, shown bigger, and the note under “Ask for changes” says what a note changes (“colors, type, layout and what they show; the live screenshots stay as they are”).
- A note now reaches the header and search too, and one note can revise several directions; the run waits until the last one arrives.
- The brief also carries the app itself (subtitle, categories, description, each language’s keywords, the icon’s colors) and each canvas’s safe area, so the idea is about this app and nothing important gets cut off.
- Loops and App Previews have full-screen player controls: back 5 s, Play/Pause, forward 5 s, time, a scrubber, and “Plays muted on repeat on the App Store”.

### Every language’s name and words

- The app name on the artwork is each language’s App Store name (*Lumen: Tagebuch* in German, *لومن: يوميات* in Arabic), not the account’s English one. The App Preview’s end card and the preview do the same.
- Claude Design writes each phrase once, in the primary language. Localize and check translates it like a caption: Captions gets a **Phrase N** column per phrase, with the same fit meter and an editor that starts from the original words. Pages from before, with every language inside them, still work and are read into Captions.
- pt-BR and pt-PT no longer share one loop: loops are kept per language and per phrase.

### Header only, or search results only

- The size menu in the plan has four choices: **Header 21:9 and search 3:2** (default), **Header 21:9 only**, **Search results 3:2 only**, **One 16:9 image for both**. Motion works for every choice but 16:9.
- With only one place, the plan names it (“Header”, “Moving header artwork in 12 languages”), and a header-only run drops “What the search artwork shows”. The brief asks for that place alone and says the other one keeps what it shows now.
- The other place keeps its earlier artwork: App Store Connect isn’t touched, and the preview still shows it as it was.

### Under the preview: the header and search details

- For a new set, a **Header and search** card under the App Store preview lists each image in the chosen language: format (*3840 × 1646 · 0:20 loop · 30 fps · H.264 · seamless · 4.9 MB*), its words (or *No line: the app name only*), its checks, and where it stands (*On App Store Connect*, *New · waits in Review & Push*, *New · stays out of the push until it’s fixed*). **View Larger** opens the viewer; a line sums up every language.

### Autopilot

- **Cancel Run…** in every stage’s footer asks first, then stops what Atlas is making and stops Claude Code. The captures and picks stay for the next start, a saved template stays in the set’s history, and nothing was sent to App Store Connect.
- A run Atlas was quit in the middle of picks up where it was when the app opens again: rendering, localizing or a revision starts again instead of sitting at “Rendering 0 of N”.
- Apple Watch has its own **Add a Screen…** and **Suggest Screens** under its screens: steps worked out by Claude Code into the watch app’s UI tests, no caption.
- Loops draw two or three at a time and an unchanged loop is reused, so a second render of the same page is quick.

### Review & Push

- Click any screenshot, header, search image or App Preview in Review & Push to see it full size over the sheet, with **Live Now** and **New** side by side (*Nothing live: Arabic shows English (U.S.)’s screenshots until this push*). Pinch to zoom around the fingers, up to 8×; double-click for 2× or Fit. The Studio’s viewer zooms the same way.
- **Pushing the extras:** one file uploads at a time while Apple processes up to 10 side by side. The section says what each file is doing (*Uploading 42% · 3.1 MB of 7.4 MB*, *Apple is processing it · 0:42 · checked 3 times*, *Placing it on Dutch*), the time so far and left, the last files done, and each tile shows its own state (*Next*, *Waiting · 6 ahead*, *Done*).
- A paused push says why and when it goes on (*App Store Connect’s hourly request limit is used up. It goes on by itself.*). Failures are one line per reason, with the files it stopped, and **Retry Failed**. Each upload gets its own name, so an interrupted push can’t fail as a duplicate next time.
- **Asset Library…** lists every image and video uploaded for the app, says which are on a page, and deletes several at once (**Select Unused**). A file a page still shows can’t be deleted.
- **Test with Product Page Optimization** says what Claude Code is doing while it makes the variant: the four steps with times, what it’s working on, what it did before, and **Start Claude Code Again** or **Copy Prompt** if it stops.

```
get_design_brief(app, run)   → … artworkDesign: { askedByThePerson, pages: [header, search], data-al marks }, canvases[].safeArea, aboutTheApp, onlyThis?
render_artwork(app, run, kind, html | direction, locale?, headline?)   // try a page: the render, the checks, wouldBeRefused
propose_direction(app, run, name, rationale, artworkDesign: { header, search }, followsTheRequest)
revise_direction(app, run, direction, artworkDesign?, last?)           // last: false when more directions follow for the same note
propose_captions(app, run, placement: "text", phrase, on, …)           // a page phrase in each language
propose_artwork_variant(app, run, html, phrases?: [{ phrase, locale, text }])   // Product Page Optimization variant of a page
```

## 9 · Built since: picking templates, concepts that move, Make Again

Board 37 draws it. Board 33 (Header style) is built now too.

**In the prototype.** Board 39 embeds the studio prototype at these states: the template picks and Choose Templates…, concepts that move before Choose, Make Again (Prototype pill → “Header fails”), and Cancel Run… in every stage’s footer.

### Screenshot style from templates

- With **From templates**, the plan shows each pick as a preview made with this app’s captions and captures: its first three slots, numbered in pick order, with **×** to take it out. A dashed **Add a template** tile and **Choose Templates…** open the picker. The note under the choice says how many are picked (*Pick at least one, up to 3.* · *2 of 3 picked.*).
- The picker is a sheet over the Autopilot sheet with the gallery’s 12 cards and its style filter (All · Simple · Bold · Elegant · Playful). **Pick** numbers a card, **Remove** takes it out, and **In use** marks the set’s current template. A fourth pick replaces the last one (*3 of 3 picked. Picking another replaces the last.*). It’s a fixed 880 pt wide, so it always shows three columns.
- From each pick, Claude Design makes one direction in the brand, and the person chooses one of them as before.

### Every concept moves before Choose

- With **Motion loop**, Design animates all three header concepts before Choose: each row says *Claude Design is animating its 20-second loop…* until its loop arrives, then shows it with a **0:20** chip. Choose plays the loops, so the person picks a moving header, not a still.

### A header that wasn’t made

- If the header page can’t be rendered (it didn’t load in a language), Ready for review says so instead of showing an empty Review & Push: *Header artwork couldn’t be made, so it isn’t in Review & Push.* The card gives the reason, and **Make Again** renders it again from the choices already made, without designing anything again. The log shows the failure in red.

Assumptions to check: how Claude Design is reached from an MCP session (answered for Atlas’s own Claude Code: it isn’t); the simulator models and Xcode version on the person’s Mac; the exact launch arguments and sample-data switch of each app. Sample data (Lumen, Northpier Brand, the directions, timings and estimates) is illustrative.

References: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications) · [App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/) · [Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) · [XCUIScreenshot](https://developer.apple.com/documentation/xctest/xcuiscreenshot) · [Model Context Protocol](https://modelcontextprotocol.io/).
