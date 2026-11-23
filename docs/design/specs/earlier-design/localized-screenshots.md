ATLAS · LOCALIZED SCREENSHOTS · ADDENDUM · OCTOBER 2026

# Localized App Store screenshots

One template, rendered the same way for every locale. Per locale only the caption and the capture change. Atlas renders, checks and queues each image; nothing reaches App Store Connect without review. An AI assistant can propose a template or captions over the local MCP server, but it never draws the app’s interface and never pushes.

**On the canvas.** *Prototype — localized screenshots* sits next to the main prototype; press Play and open the dashed Prototype pill for the three flows. Boards 11–14 embed it at each state, in light and dark. *Components — screenshots* and *Starter templates* are drawn by the same layout engine and renderer (*Screenshot renderer*), so every image on the canvas follows the template model in section 3.

1. Where it lives
2. Screens
3. The template model (the contract)
4. Fit, right to left and fonts
5. Checks
6. Proposals
7. MCP tools for screenshots
8. Pushing
9. Components and tokens
10. Decisions the brief left open
11. What SwiftUI on macOS can’t do as drawn
12. About the sample data

## 1 · Where it lives

- **Store Page → Screenshots.** Screenshots belong to an App Store version, like the description, so they sit with the rest of the store page instead of a fifth toolbar section. The view replaces the old read-only strip.
- A **screenshots bar** under the Store Page bar: *Sets | Template | Captions | Captures* (Captions shows a red count when captions overflow), the display-type menu, the locale-scope button, render status and thumbnail size.
- The **template editor hides the app library** while it’s open (`columnVisibility = .detailOnly`) to make room for the canvas, the stress strip and the inspector. Leaving the editor brings the sidebar back.
- **Proposals** show as a quiet glass pill in the window toolbar, “CC · 2 proposals”, with a popover listing proposals per app. There’s no badge on the Dock icon and no notification.

| Concept | What it is | Keyed by |
| --- | --- | --- |
| **Capture** | A real screenshot of the app. Atlas never draws or edits it (App Review guideline 2.3). | locale × display type × slot |
| **Template** | The layout, versioned: canvas, background, device frame, caption box and style, fit rules, safe areas, fonts per script, the right-to-left rule and per-slot overrides. | app (one template per app; custom product pages later get their own) |
| **Caption** | A headline and an optional subhead. States: missing, machine-translated, edited, proposed, overflowing. | locale × slot |
| **Render** | The image for one locale × display type × slot, with its check results. Derived, never edited. | render key = template content hash + caption + capture id |
| **Proposal** | A change an assistant sent: who, when, what, and the template version it was based on. | app |

## 2 · Screens

### Sets

- Rows are locales, columns are slots (5 for Lumen, up to 10), with a read-only **Preview** column for existing App Previews (play glyph, duration, lock). Slots 1–3 carry a magnifier: on iPhone they also show in search results.
- Groups: **Localized sets** (primary first), **Restored · not rendered**, and a collapsed **Use English (U.S.) screenshots · 27** that expands to dimmed fallback thumbnails.
- Row header: flag tile, name, and a one-line summary (“1 check failed · 4 not pushed”, “UI not localized”, “Live”).
- **Cell** = render plus a state badge underneath, so state never relies on color alone. A “UI” chip marks a capture showing the English interface; a CC monogram marks a cell with a proposal waiting.
- States: *Live* (matches App Store Connect) · *Not pushed* (blue dot) · *Proposal waiting* · *Check failed* (red ring plus the reason: Overflow, Missing glyphs, Wrong size) · *UI not localized* · *English (U.S.)* (missing, falls back, dimmed) · *Rendering* (spinner) · *Restored* · *No caption* · *Uploaded by hand* (live, not managed by a template).
- Thumbnail sizes S / M / L (44 / 64 / 92 pt wide for iPhone, 84 / 116 / 164 for iPad landscape). M shows a caption you can judge.
- A red banner names the first failing render and opens it; failing renders never enter Review & Push.

### Full-size viewer

A sheet showing one slot at about 262 pt wide (600 for iPad landscape). It steps through the localized locales with ◀ ▶ and a list where each row has a state dot. The side panel lists the checks, the caption with its fit meter and provenance, and the capture’s file, pixel size and whether its interface is localized. The sheet ends with Edit Caption, Open in Template Editor and Done.

### Locale scope

A sheet with all 39 locales: a checkbox, how many captions exist, whether its captures have their own interface, and what is live now. Shortcuts: Locales with Localized Captures, All 39, Only English (U.S.). The footer estimates images, requests and the share of the hourly limit. Leaving a locale out never deletes what’s live there. Restored locales show *Use Template Again*.

### Template editor

- **Header:** template name, version, “Unsaved edits” with **Save as vN**, the CC tag when the current version came from a proposal, History and Starter Templates….
- **Controls:** slot picker (1 Today … 5 Privacy), locale menu, and a switch for safe areas and the caption box. The guides draw the safe area dashed in blue and the reserved caption box solid, in red when the caption overflows or a glyph is missing.
- **Canvas:** a large render of the slot on the neutral stage.
- **Stress strip:** the same slot in four locales, updating live: the primary; the longest of German and Finnish, measured per slot; Arabic; Japanese. Each has a fit meter and its check. A stress locale with no caption yet previews a translation of the English caption, labelled “preview translation”.
- **Inspector:**
  - Canvas: display type, orientation, output size and API display type.
  - Background: solid, gradient (two stops and an angle) or panorama.
  - Device: on or off, finish, width.
  - Caption: placement above the device or in a band, alignment, headline font, size in u, color.
  - Fit: maximum lines, smallest size, shrink to fit, hyphenate.
  - Fonts by script: one row per script, with a fallback picker and a status.
  - Right to left: mirror the layout.
  - Safe areas: top and sides.
  - This slot: Standard or Hero layout, headline size override, Reset Slot.
- **History** popover: versions with date, author and note; a CC tag for versions that came from accepted proposals. **Restore This Version** creates a new version from the old one.
- **Starter templates** (first run, or the sheet): *Caption above device*, *Full-bleed with caption band*, *Panorama*. Each card is previewed with real renders. Switching keeps captions and captures.

### Captions

- A matrix of locales × slots. Each cell shows the headline (two lines), the subhead for slot 1, a **fit meter** and its label, and tags: MT (purple), CC, edited dot. A missing caption shows “Write caption” for the primary and “Missing” elsewhere.
- **Translate Missing…** reuses the Translation settings: Apple Translation on this Mac, an AI provider, or your assistant over MCP, which sends proposals instead. Tone and glossary come from Settings too. Each caption is measured as it arrives; ones that don’t fit are flagged, never cut.
- Filter: All · Needs attention (overflowing, machine-translated, missing).
- **Editor panel** for the selected cell:
  - the English source;
  - headline and subhead fields, which follow the locale’s reading direction;
  - a large fit meter with its zones, plus the line count and the size in u;
  - a preview showing the caption box;
  - Mark Reviewed, for machine-translated captions;
  - **Suggest a Shorter Version**, which uses the translation provider and shows its own fit meter, with Use This and Keep Mine.
- Accepted machine text stays tagged until reviewed or edited, as in the listing editor.

### Captures

- Empty state: a drop zone for a folder plus three sources:
  - fastlane snapshot output (`<locale>/<device>-NN_Name.png`);
  - Xcode test results (screenshot attachments in an `.xcresult` per language);
  - the live screenshots in App Store Connect, with a warning that they may already have captions.It also explains guideline 2.3 and the “UI not localized” fallback.
- **Matching:** each file → locale, display type, slot, with a summary (52 matched · 3 need you). Rows that need you explain why and offer a choice:
  - “pt” isn’t an App Store locale: choose Portuguese (Brazil) or Portuguese (Portugal), or skip.
  - A 6.1″ capture for the 6.9″ set: skip it, or use it scaled up 113%.
  - A slot 6 when the template has 5: skip it, or add slot 6.Nothing is uploaded at this step.
- **Coverage:** locales × slots with the raw captures, labelled Localized, English UI or Wrong size, plus the source per locale.
- The first import sets the scope to the locales whose interface was captured. The other locales fall back visibly.

### Proposals

- A sheet with the list on the left and detail on the right. Each card: CC tag, time, title, “Template v4 → v5 · 4 changes” or “3 captions · German”, status (Waiting, Stale, Accepted, Partly accepted, Rejected).
- **Template proposal:** the assistant’s reason, the changes (old → new), and **before/after rendered across the stress strip** for a chosen slot, with fit labels. Reject, or **Accept as v5**.
- **Caption proposal:** per item a checkbox, old (struck) → new, fit meters for both, and the proposed render. Reject All · Accept n Selected · Accept All.
- **Stale:** the proposal was based on an older version. It lists what changed since and, for each field both sides changed, asks “Keep yours” or “Use Claude Code’s”. Then Rebase onto vN, or Discard.
- **Provenance:** “Proposed by Claude Code · 10:42” on captions, cells, the viewer and template history. It stays after acceptance until a person edits the item.
- If the assistant disconnects, a neutral banner says so; its proposals stay.

### Settings → AI Assistants

- Server switch (off by default) with status and address.
- **What a paired assistant can do**, in plain words. It can read this app’s captures, captions and templates, measure a caption, render a preview, and send proposals. It can’t push, change anything without review, draw the interface, or see the API key.
- **Paired assistants:** each has its own token, connection status (connected, disconnected with last seen, paired but idle) and **Revoke**. **Pair Assistant…** opens a sheet: choose a client, copy the command with that client’s token (or use a 6-digit pairing code that expires in 10 minutes), watch it connect.
- Permissions gain **Propose screenshot templates and captions**. The activity log shows the screenshot tools, including refusals and their reasons.
- This replaces the single shared token from the first addendum. Per-client tokens are what make Revoke per client possible.

### Review & Push · Screenshots

- One group per locale × display type: old (live) → new thumbnails per slot, a checkbox per image and per group, and discard per image (“keep what’s live”). Restores are labelled “Restore from Oct 12”. Groups with accepted proposals carry the CC tag.
- Failing renders are listed as not included, with Show in Captions. Discards can be undone.
- The footer estimates requests, minutes and the share of the hourly limit. The buttons are Push n Selected and Push n Images.
- **Progress:** one row per image: queued → reserving → uploading n% → committing → done (Apple is processing) or failed, with the reason. The rate-limit meter stays. Cancel Remaining; when done, Retry Failed and Done.

### Activity and restore

Every screenshot push lists the sets it replaced, which are **kept on this Mac**. **Restore Previous Screenshots…** opens a sheet: pick a locale, see the kept set per display type, and queue it for review. A locale that had none says so: going back means leaving it out of the scope. A restored locale is pinned, so later pushes don’t replace it again until you choose *Use Template Again*.

### System states

The states covered on boards 11–14:

- no captures yet;
- no template yet, with the template picker (14 templates, filtered by style);
- rendering in progress, with a counter and a spinner per cell;
- a failed check: overflow, missing glyphs or wrong size;
- no editable version, where renders wait and pushing is off;
- the server off, and an assistant disconnected;
- a stale proposal;
- a partial push failure.

## 3 · The template model (the contract)

The renderer and the MCP tools read and write the same JSON. An assistant that can read this section can propose a valid template. All lengths are either **fractions** of the canvas (0–1) or **u**, where **1 u = the canvas’s short side ÷ 1320**. A 112 u headline is 112 px on a 1320 × 2868 iPhone canvas and 175 px on a 2752 × 2064 iPad canvas, so one template holds across display types.

```
{
  "schema": "atlas.screenshot-template/1",
  "id": "lumen", "name": "Lumen · Caption above device", "version": 4,
  "starter": "above",
  "canvas": { "iphone": "portrait", "ipad": "landscape" },
  "bg": { "kind": "linear", "angle": 168, "stops": ["#7A80FF", "#3A2FB8"] },
  "device": { "show": true, "width": 0.80, "color": "#141416", "offset": 0, "bleed": 0.07 },
  "caption": {
    "placement": "above", "align": "center", "gap": 0.028,
    "ink": "#FFFFFF", "subInk": "rgba(255,255,255,0.84)",
    "band": { "color": "#17143D", "pos": "bottom" },
    "headline": { "font": "SF Pro Display", "weight": 700, "size": 112, "min": 80,
                  "lh": 1.08, "maxLines": 2, "tracking": -0.01 },
    "subhead":  { "font": "SF Pro Text", "weight": 500, "size": 50, "min": 42,
                  "lh": 1.24, "maxLines": 2 }
  },
  "fit": { "shrink": true, "hyphenate": false },
  "rtl": { "mirror": true },
  "safe": { "top": 0.06, "side": 0.075, "bottom": 0 },
  "fonts": { "display": "SF Pro Display",
             "fallback": { "arabic": "SF Arabic", "hebrew": "SF Hebrew", "ja": "Hiragino Sans",
                           "zh-Hans": "PingFang SC", "zh-Hant": "PingFang TC", "ko": "Apple SD Gothic Neo",
                           "thai": "Thonburi", "devanagari": "Kohinoor Devanagari",
                           "cyrillic": "SF Pro Display", "greek": "SF Pro Display", "vietnamese": "SF Pro Display" } },
  "slots": [
    { "layout": "hero", "over": {} },
    { "layout": "standard", "over": { "caption.headline.size": 104 } },
    { "layout": "standard", "over": {} }, { "layout": "standard", "over": {} }, { "layout": "standard", "over": {} }
  ]
}
```

| Field | Type · unit | Rules |
| --- | --- | --- |
| version | integer | Set by Atlas. Each save, accepted proposal or restore makes a new one. Proposals name the version they’re based on. |
| canvas.<display> | "portrait" | "landscape" | Output is always one of Apple’s exact sizes: iPhone 6.9″ 1320 × 2868 / 2868 × 1320 (`APP_IPHONE_67`), iPad 13″ 2064 × 2752 / 2752 × 2064 (`APP_IPAD_PRO_3GEN_129`). Keys for Mac, Watch, TV and Vision Pro use the same shape when an app needs them. |
| bg | kind: solid · linear · image · panorama | `stops` are hex colors; `angle` in degrees for linear. `image` takes an asset id. `panorama` spans every slot: slot *i* shows the window from *i × width*. |
| device.width | fraction of canvas width | 0.6–0.9. In landscape it shrinks to fit the height left under the caption. |
| device.offset | fraction | Horizontal offset, alternating per slot (panorama). Mirrored in right-to-left locales. |
| device.bleed | fraction of canvas height | How far the frame may run past the bottom edge. |
| caption.placement | "above" | "below" | "band" | Band puts a solid bar at `band.pos` and lets the capture fill the canvas (device ignored). Below puts the caption at the bottom, inside `safe.bottom`, and the device leans out of the top edge. |
| device.tilt | { rz, ry, rx } degrees | Rotate, turn and lean back. Drawn as a 2D transform (rotate, skew, scale), not real perspective, so dozens of thumbnails stay cheap to draw. Mirrored in right-to-left locales. Usually set per slot. |
| device.dx, device.dy | fraction | Extra shift right and down, on top of `offset`. Mirrored horizontally in right-to-left locales. |
| caption.headline.upper | boolean | Uppercases with the locale’s own rules (Turkish dotted İ, German ß → SS) before measuring. |
| caption.headline.emph | { on: "first" | "last", weight, font?, italic? } | Styles one line after wrapping, so it follows each language’s breaks. “first” needs two or more lines; “last” also styles a one-line caption. |
| caption.headline.mark | { color, pad, rot, radius, shadow } em | A bar behind each wrapped line, rotated alternately. The fit width shrinks by the padding. |
| caption.headline.shadow, italic | CSS text-shadow in em · boolean | Scales with the headline size. |
| deco | [ { type, x, y, w, h?, color, z, rot?, op? } ] | `type`: `shape` (sparkle, blob, swoosh, wave, arc, petal, circle, chevrons), `laurel` (value + stars) or `badge` (value). x and w are fractions of the width, y and h of the height; h defaults to square. `z`: back (behind the device) or front. Mirrored in right-to-left locales; laurels and badges keep their text readable. Text is numbers and symbols only, so it never needs translating. |
| caption.align | "center" | "start" | Start means the reading direction’s start: left in English, right in Arabic. |
| caption.headline.size, min | u | `min` ≤ `size`. Shrink-to-fit steps down by 2 u. |
| caption.\*.maxLines | 1–3 | The caption box is **reserved** at maxLines × size × lh, so the device never moves between locales. |
| safe.top, safe.side | fraction | Captions stay inside. Corners are rounded by the App Store, so nothing important goes there. |
| fonts.display | font name | A system font or an uploaded font. Its coverage is read from the font’s cmap; scripts it can’t draw use `fallback`. |
| fonts.fallback.<script> | font name | null | Scripts: latin, cyrillic, greek, vietnamese, arabic, hebrew, ja, zh-Hans, zh-Hant, ko, thai, devanagari. **null with no coverage = a failed check**, never a silent box. |
| slots[i].layout | "standard" | "hero" | Hero: headline ×1.06, room for a subhead, device ×0.96. Slot 1 is hero by default. |
| slots[i].over | { "dotted.path": value } | Any template field, for that slot only. Removing a key returns it to the template value. |

**Order of resolution** for any value: `slots[i].over[path]` → the template’s value at `path`. One template per app today; custom product pages will hold their own templates under the same schema, keyed by page id.

### Templates

**Templates…** (and the first-run picker) offer 14 templates, filtered by style. Each is just a template JSON with per-slot overrides, so everything in it is editable afterwards and it renders every language.

| Template | Style | What it does | Display font · scripts |
| --- | --- | --- | --- |
| **Caption above device**, **Full-bleed with caption band**, **Panorama** | Simple | The original three. | SF Pro Display, New York |
| **Bold Stack** | Bold | Heavy uppercase with a lighter first line, angled phones, a circle behind; slot 1 flips to ink with a rating laurel. | Archivo Black + Archivo · Latin |
| **Swoosh** | Bold | Green and white trade places per slot, a ribbon behind the phone, a badge on slot 3, italic last line. | Playfair Display · Latin, Cyrillic, Vietnamese |
| **Poster** | Bold | Tall condensed uppercase on black and grey, white shapes. | Anton · Latin, Vietnamese |
| **Cinema** | Elegant | Serif caption below, phone leaning out of the top, deep red fade, laurel on slot 2. | Playfair Display |
| **Spotlight** | Elegant | Big serif headline on a magenta glow, a pink phone lying back, laurel on slot 4. | Playfair Display |
| **Editorial** | Elegant | Light first line over a bold statement, aligned to the start; dusk, lavender and light slots. | Poppins · Latin, Devanagari |
| **Sparkle** | Playful | Bold last line, sparkles, tilted phone on purple; slot 3 turns light. | Poppins |
| **Playful** | Playful | Script headline with a drop shadow, white petals, an orange slot with a laurel. | Lobster · Latin, Cyrillic, Vietnamese |
| **Highlight** | Playful | Every line on its own tilted marker, purple phone, laurel on slot 1. | Fredoka · Latin, Hebrew |
| **Arcade** (new) | Bold | Huge white Boldonse caps on electric blue; big straight phones (85% wide, top at 27%) run off the bottom. Slot 1: a game controller over the corner. Slot 2: a hand-drawn underline and chess pieces. Slot 3: **Two phones**. Slot 4: a white corner curve and a pointer. Slots 4 and 5: one figure spans the seam. Slot 5: a star and a die. | Boldonse · Latin; other scripts fall back, drawn heavy |
| **Social Proof** (new) | Bold | A light kicker line over a heavy headline. Ink, lilac and mist backgrounds alternate; big tilted phones bleed off the edge. Slot 1: rating laurel. Slot 2: **Reviews** layout, no device. Slot 3: an illustration overlaps the phone. Slot 5: a hand holds the phone. | Poppins · Latin, Devanagari |

### Arcade: what’s new in the engine

- **Two phones layout.** A slot can be *Two phones*: its own capture in front, and the capture of the slot before it behind, higher up and partly off the edge. Both keep the real iPhone shape; the canvas crops what runs off.
- **Fixed device top.** `device.top` pins the phone’s top edge (27% of the height here) instead of following the caption box. If a language needs one more line, the phone moves down just enough; it never overlaps the caption.
- **Tight caption box.** `caption.headline.tight` sizes the box to each language’s real lines, so a two-line English caption doesn’t reserve room for a third.
- **Measured font widths.** Boldonse mixes round, wide letters (C, G, O, Q, W) with narrow ones, so the engine wraps it with a measured width per letter instead of an average. Scripts it doesn’t draw use the fallback fonts at a heavy weight, so Arabic and Japanese hold their own next to the Latin caps.
- **Props.** A new decoration type draws multi-color vector art: controller, chess pieces, die, figure, underline, asterisk, curved arrow, corner curve, pointer and star. Each can be hidden or removed per slot; marks in a single color take the color picker. Props are stand-ins drawn by the template, never cut out of a reference.
- **Props stay off the caption.** A prop can be anchored to the caption (the underline sits under the last line; the asterisk follows the end of line 1), and each one says what to do when a language’s caption runs into it: move below the caption, step aside, or hide.
- **One figure across two slots.** The figure on slot 4 continues on slot 5 at the same scale, placed one canvas width apart, so it lines up when people swipe. In Arabic and Hebrew the layout mirrors and the figure meets at the other edge, matching the right-to-left order of the store.
- **No capture yet: black screens** (all templates). An empty device is a black, switched-off screen instead of the striped placeholder, so a set without captures still looks like the finished design. Missing captures are still flagged under each screenshot.
- **Real ratings on laurels** (all templates). A rating laurel shows the app’s real App Store rating in each country by default, read daily from the App Store (average and count per storefront, from the iTunes Lookup API; the App Store Connect API has no average rating). Where the app has no ratings yet, the laurel is left out. *Type It* sets a value by hand, which is checked before pushing. In landscape (iPad, Mac), laurels and badges keep their size and stay inside the canvas.
- **Mac and iPhone Duo** (all templates): the engine also lays out Mac App Store screenshots (2880 × 1800, always landscape) with Lumen’s Mac window and menu bar on a MacBook, and the iPhone Duo inner display (2007 × 2853). A template can set its own landscape values; Arcade uses smaller caps there and lets the device follow the caption.
- **Device frames are 3D** (all templates): titanium rim, a visible side edge and buttons that follow the angle, screen glare and a soft floor shadow.

Based on a reference set for a game. Its interface, logos and the photo of a child were left out; the figure is a flat silhouette to replace with your own artwork.

### Social Proof: what’s new in the engine

- **Kicker line.** A template can set `caption.kicker` (font, weight, size, one line). The kicker is a short topic line per slot and language, edited in Captions next to the headline and translated like it. Empty kicker: the slot shows the headline only. With a kicker, the headline sits right under it and the device follows the text’s real height.
- **Reviews layout.** A slot can be *Reviews*: no device, three 5-star App Store reviews under the headline, centered, each with the reviewer’s first name and a drawn rule above. Atlas picks them from that language’s storefront (customer reviews in App Store Connect). With fewer than three, it uses the primary language’s, translated and marked for you to approve. Only real reviews: nothing is written for you.
- **New shapes** for decorations: rule, moon, palm and fingers (a hand holding the phone). The illustration on slot 3 is a placeholder made of shapes; with a design project connected, Claude Design draws one in your brand.
- Left out on purpose from the example it was based on: press logos (other brands’ marks, and Apple doesn’t allow awards it can’t verify), and the drawn character (someone else’s artwork).

- **Fonts are bundled** with Atlas (all under the SIL Open Font License), so a template looks the same on every Mac. The card says which scripts the font draws; the others use the fallbacks in *Fonts by script*, as before.
- **Ratings and badges must be true.** Before pushing, Atlas compares the number with the app’s App Store rating in each country and flags a slot where it’s higher, since Apple rejects misleading screenshots.
- **Inspired by common App Store layouts, not copies.** No brand names, logos or stock people. Product props (carts, boxes), press logos and quote slides from the references were left out: they need assets or text that would have to be translated.
- **Inspector additions:** Below placement; frame color; angle per slot (rotate, turn, lean back); uppercase; emphasis on the first or last line (light, heavy or italic); highlight bars; a slot’s own background; decorations per slot (add rating, sparkle, shape or badge; edit value and color; remove).

## 4 · Fit, right to left and fonts

```
box.w = canvas.w − 2 × safe.side × canvas.w          (portrait, centered)
box.h = maxLines × size × lh                          (reserved, per text block)
for size from headline.size down to headline.min, step 2 u:     (only size if shrink is off)
    lines = wrap(text, script, size, box.w, hyphenate)
    if every word fits and lines ≤ maxLines → fits at size  (“shrunk” when size < headline.size)
otherwise → overflow: render at min and report how many lines too many
fill = text width at full size ÷ (maxLines × box.w)    → the fit meter
```

- **Fit meter.** The bar shows *fill*. The first tick (1.0) is what fits at full size. The second (size ÷ min) is the most that fits at the smallest size. Past it, overflow. Labels: “Fits at 112 u”, “Shrinks to 92 u”, “1 line too many at 80 u”. Captions have no character limit; this replaces the counter.
- **Line breaking** in the app uses Core Text with the locale: word boundaries for Latin, Cyrillic, Greek, Arabic and Hebrew; dictionary breaks for Thai; between characters for CJK, with kinsoku (no line starting with 、。」？ and similar). Hyphenation, when on, uses the locale’s hyphenation dictionary and only for words wider than the box.
- **Right to left.** Text in Arabic and Hebrew always runs right to left, and start alignment means right. With `rtl.mirror` on, the layout flips: device offsets, start-aligned caption boxes, and the panorama. The panorama is mirrored *and* keeps slot order, so it continues as people swipe from right to left. **Captures are never mirrored**: they’re the real interface, which already mirrors itself.
- **Fonts.** For each locale the script picks the font: the display font if it covers the script, else its fallback. A display font is tested against every character of every caption, not only the script’s main range. Vietnamese needs the stacked diacritics, for example.

## 5 · Checks

| Check | Fails when | Blocks push |
| --- | --- | --- |
| Size and format | Never for renders: output is one of Apple’s pixel sizes, PNG, RGB, flattened, no alpha. Shown as a passed check. | — |
| Fit | Headline or subhead needs more lines than allowed at the smallest size, or one word is wider than the box with hyphenation off. | Yes |
| Glyphs | A character has no glyph in the display font or the script’s fallback. | Yes |
| Capture size | The capture comes from another device class (an iPad capture in an iPhone slot), or a full-bleed capture would be cropped or scaled more than 10%. | Yes |
| UI not localized | The capture shows the primary locale’s interface. | No · warning |
| Caption, capture present | Either is missing: the cell shows the fallback until it exists. | Not pending |

## 6 · Proposals

- A **template proposal** is a list of operations on dotted paths, with the version it was based on: `{ basedOn: 4, ops: [{ op: "replace", path: "caption.headline.size", value: 104 }, …], reason }`. Accepting applies them and saves a new version tagged with the assistant.
- **Stale** = based on an older version than the current one. Rebasing re-reads each path. Untouched paths apply as proposed. Paths both sides changed ask which value wins. The result is a new pending proposal on the current version.
- A **caption proposal** is per locale and slot: `{ loc, slot, headline, subhead? }`. It is measured against the *current* template when shown, so a template change never makes caption proposals stale. Their fit simply updates.
- Accepted captions are tagged “Proposed by Claude Code” until someone edits them. Accepting never pushes. The changed renders join Review & Push like any others.

## 7 · MCP tools for screenshots

Added to the existing local server, behind the new “Propose screenshot templates and captions” permission. Read tools need only the server.

| Tool | Input | Output |
| --- | --- | --- |
| get\_screenshot\_context | `appId, version?` | Display types and sizes, slot names, locales in scope, primary captions, listing name and subtitle, template version |
| list\_captures | `appId, displayType?, locale?` | `[{captureId, locale, displayType, slot, source, localizedUI, pixelSize}]` |
| get\_capture | `appId, captureId` | The image, as MCP image content, so the assistant can see the interface it is captioning |
| get\_template | `appId, version?` | The template JSON (section 3) and its history |
| get\_captions | `appId, locales?` | Per locale and slot: headline, subhead, state, fit result |
| measure\_caption | `appId, locale, slot, headline, subhead?, templatePatch?` | `{fits, size, lines, fill, label, glyphsMissing}`, so the assistant can check before proposing |
| render\_preview | `appId, locale, slot, displayType, templatePatch?` | A PNG rendered by Atlas (never by the assistant) |
| propose\_template | `appId, basedOnVersion, ops[], reason` | `{status: "queued" | "refused", proposalId?, stress: [{locale, fits, label}], reason?}`. Refused for unknown paths, values out of range, a fallback set to a font that can’t draw the script |
| propose\_captions | `appId, items: [{locale, slot, headline, subhead?}], reason` | Per item queued or refused. Refused when it doesn’t fit the current template, has missing glyphs, or names an unknown locale. The reason says by how much: “needs 3 lines at 72 u; the template allows 2” |
| list\_proposals | `appId` | `[{proposalId, kind, basedOn, status: pending | stale | accepted | partial | rejected}]` |

**Prompts:** `/mcp__atlas__translate_captions` (fills missing captions as proposals), `shorten_overflowing_captions`, `revise_template` (asks for a revision that keeps every locale fitting, checked with `measure_caption` and `render_preview`). There is no tool to push, upload, delete screenshots, or write to captures.

## 8 · Pushing

- **Per image:** reserve (`POST /v1/appScreenshots` with file name and size) → upload the parts to the returned operations → commit (`PATCH` with `uploaded: true` and the MD5 checksum) → Apple processes. About 4–5 requests per image, plus one delete per replaced image and one reorder per set.
- **Order:** new images are committed **before** old ones are deleted, and each set is reordered last, so a failure never leaves a live set with a gap. Before deleting, Atlas downloads the old image to `~/Library/Application Support/Atlas/Backups/<app>/<date>/`; that is what Restore uses.
- **Volume:** 39 locales × 10 slots × 2 display types is about 780 images, a few thousand requests against roughly 3,600 an hour. So the scope sheet shows the cost before anything is queued, uploads run a few at a time, and when the hourly budget runs out the push pauses with a countdown, then resumes.
- **Unchanged renders are skipped:** the render key compares the template content, caption and capture, so re-saving a template without changes pushes nothing.
- App Previews are listed read-only; nothing here uploads or deletes them.

## 9 · Components and tokens

- **New components**, on *Components — screenshots* in light and dark:
  - screenshot thumbnail cell, with 12 states;
  - fit meter (fits, shrinks, overflows, empty);
  - stress strip;
  - render check badge;
  - template inspector sections;
  - font-per-script row;
  - capture drop zone (empty, hover, imported, wrong) and matching row;
  - proposal card;
  - AI provenance badge;
  - upload progress row.
- **One new token: `stage`**. It is the neutral ground behind renders (light #E7E7EC, dark #0E0E10, with Increase Contrast variants), so white or near-black screenshots never melt into the window.
- **No new color for “AI proposed”.** It reuses the existing neutral assistant tag: outlined, with a monogram. Color stays reserved for meaning: red for failed checks, yellow for UI not localized, purple for machine translation, blue for not pushed.
- **SwiftUI mapping:**
  - the sets matrix is a `LazyVGrid` inside a `ScrollView([.horizontal, .vertical])` with pinned headers;
  - renders come from an `ImageRenderer` of a SwiftUI `ScreenshotView(template:caption:capture:)`, cached by render key;
  - the inspector is a `Form` with `.formStyle(.grouped)`;
  - the viewer and proposals are sheets;
  - History is a `.popover`.

## 10 · Decisions the brief left open

- **Screenshots sit inside Store Page**, not in a fifth toolbar section: they belong to a version, and ⌘1–⌘4 stay as they are.
- **Renders are derived, never stored as edits.** “Not pushed” means the render key differs from what’s live. Discard means “keep what’s live for this image”, until something changes again.
- **The caption box is reserved at its maximum size**, so the device and the composition stay identical across locales. Short captions are centered in the box.
- **Sizes in u** (short side ÷ 1320), so one template works for iPhone and iPad, portrait and landscape.
- **The stress strip picks the longest locale per slot** (German or Finnish, measured), and previews a translation when a stress locale has no caption yet.
- **Failed checks block push. “UI not localized” only warns**: shipping English UI with a localized caption is a choice, not an error.
- **The first import proposes the scope**: the locales whose interface was captured.
- **Template edits are a draft until saved**, but renders update live. Accepting a proposal or restoring creates a version immediately.
- **Only template proposals go stale.** Caption proposals are re-measured against the current template.
- **Restoring pins a locale**, so the next push doesn’t undo the restore.
- **Per-client tokens with Revoke** replace the single shared token, plus an optional pairing code for clients that ask for one.
- **The template editor hides the sidebar** while open.
- **Watch, TV, Vision Pro and Mac** appear in the display menu as not applicable to Lumen, with the reason, so the model is visibly open to them.

## 11 · What SwiftUI on macOS can’t do as drawn

- **Measuring text the way the render will.** SwiftUI `Text` doesn’t report line breaks. The fit engine has to run on Core Text (`CTFramesetter`) with the exact font and locale, and the render must use the same lines, so `ScreenshotView` draws pre-broken lines rather than letting `Text` wrap.
- **Glyph coverage** needs `CTFontGetGlyphsForCharacters` per character. SwiftUI falls back to system fonts silently, which is exactly what the check must catch.
- **Exact pixel output:** `ImageRenderer` needs `scale = 1`, a fixed proposed size equal to the canvas, an opaque background and an RGB colour space. Then strip alpha before PNG encoding (`CGImage` with `noneSkipLast`), or App Store Connect rejects the image.
- **Hundreds of live thumbnails** can’t each be a live SwiftUI view. Render once to images, cache by render key, and draw `Image` in the grid; re-render in a background task when the key changes.
- **Device frames** aren’t a system asset. Apple publishes product bezels in its design resources; the app ships them as image assets, used under Apple’s terms for marketing materials.
- **Hyphenation** in Core Text needs `kCTParagraphStyleSpecifierHyphenationFactor` (or `NSParagraphStyle.hyphenationFactor`) with the locale set on the attributed string.
- **Reading `.xcresult`** means calling `xcrun xcresulttool`, which a sandboxed Mac App Store app can’t run. Use a user-selected folder and a helper, or support folder and fastlane imports only in the sandboxed build.
- **Drag-and-drop of a folder** needs `.dropDestination(for: URL.self)` plus a security-scoped bookmark to re-import later.
- **Two-axis scrolling with a pinned header row and column** isn’t built in. Use `ScrollView([.horizontal, .vertical])` with a manually offset header, or an `NSCollectionView` wrapper.

## 12 · About the sample data

The sample data is illustrative:

- the captions in 39 locales;
- the mock Lumen interface in 10 languages;
- the live and backed-up sets;
- the proposals;
- the request counts.

Text widths are estimated per character in this prototype; the app measures with Core Text. Fonts render with whatever the viewer’s browser has: on a Mac, SF Pro, New York, Hiragino, PingFang and friends; elsewhere, close fallbacks. “Northpier Display” stands in for an uploaded brand font that covers Latin only.

References: [Apple, screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications) · [App Store Connect API, app screenshots](https://developer.apple.com/documentation/appstoreconnectapi/app-screenshots) · [App Review guideline 2.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).
