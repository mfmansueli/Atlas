# Atlas — design handoff (23 November 2026)

The new layout for Atlas, the native macOS app for App Store Connect. Everything here comes from the design canvas. The canvas is private, so this folder is the copy to build from.

## Read in this order

1. `specs/00-design-system.md` is **the source of truth**: colour, section icons, type, buttons, badges, shape, depth and motion, each with the SwiftUI to build it with. When anything else disagrees with it, it wins.
2. `specs/10-built-decisions-and-differences.md` lists the decisions taken while building the clickable prototype and where it differs from older specs.
3. The section specs `01`–`11`. Each file starts with dated updates (“Update, November 22”, and so on). **A later update replaces what the text below it says.**
4. `screens/` holds a picture of every screen and state, drawn from the prototype at 1×:
   - `app/`: the main window, one file per scene. A `-dk` suffix is the dark appearance; `tour*` is the first-run tour; `stg*` is Settings opened over the app; `ap-*` are the Autopilot effects.
   - `settings/`, `help/`, `welcome/`, `menu-bar/`, `analytics-new-data/`: the other windows and states.
5. `prototype/` holds the source of the clickable prototype. Use it to find the exact copy, states, numbers and behaviour of a screen. **It is not code to port.** It is HTML in a canvas format:
   - `{{name}}` is a value from the view model.
   - `<sc-if>` and `<sc-for>` are if and for.
   - `<dc-import>` embeds another file.
   - The view models are in `renderVals()` in the script at the bottom.
   - `Redesign.dc.html` is the main window, with scenes such as `ov`, `sp-all`, `pr-open` and `rv-all`. `Settings`, `Help` and `Welcome` (which includes the menu bar) are the other windows. `AnData` is the newer Analytics data, not yet merged into the main window. `Toolbar` is the focused toolbar prototype; it is already merged into `Redesign`. `DS-Specimen` is the design-system board.

## Earlier design

`specs/earlier-design/` holds the specs from before the redesign. They are still useful for behaviour: how suggestions work, App Privacy and Accessibility, screenshots, Autopilot and the data model. Their visuals and navigation are superseded. Where they disagree with the files above, the files above win.

## Not verified

Every “To check” and “To validate” box in the specs is something nobody has confirmed. These include App Store Connect API endpoints and fields, report names, TipKit and Liquid Glass API names, and rate limits. Check each against Apple’s current documentation before building on it.
