# Atlas copy export

An inventory of the text in Atlas at commit `1d6b5ee9` (main, 2026-11-23), for the copy rewrite. The app wasn't changed. Everything here was generated from the sources and from a Release build made outside the repo.

## Files

| File | What it is |
|---|---|
| `copy-inventory.csv` | One row per string occurrence: 14,769 rows. 12,240 seen by the person, 41 probably seen (`person?`, not confirmed), 2,488 read only by the assistant. |
| `screens.csv` | 288 rows (283 real, 5 regex false positives kept and marked): windows, sections, pages/tabs, Settings panes, sheets, alerts, popovers, whole-window viewers, menus, menu bar menus, notifications, panels, tips, each with how to reach it. |
| `base-texts/` | Copies of the files where the text is written down, grouped by purpose. `base-texts/manifest.csv` lists every file. |

## How it was built

1. **Localizable strings.** The Release build emits a `.stringsdata` entry for every `String(localized:)` and every SwiftUI `LocalizedStringKey` literal (`Text("…")`, `Button("…")`, `.help("…")`, …), with file, line and column. These rows have `catalog = localizable (compiler-extracted)` and `key` = the exact key Xcode will put in a String Catalog. The repo has **no `.xcstrings`/`.strings` file yet**, so these keys aren't translated anywhere. `base-texts/string-catalogs/Localizable.extracted.xcstrings` is a generated draft catalog with those 9,463 keys; it isn't in the app.
2. **Hard-coded strings.** A Swift lexer read every literal in `Atlas/` and `MCPBridge/` and kept the ones that are text rather than identifiers, API values, JSON keys, logs, SF Symbol names, regexes, CSS/HTML/SVG or data tables. These rows have `key = literal`.
3. **Extras.**
   - Help articles: one row per heading, paragraph, step or list item of each `.md`.
   - The menu items macOS adds itself, read from the running app's menu bar.
   - Every place that shows an error's own `localizedDescription`.

Left out: `#if DEBUG` code, `#Preview` blocks, the `Atlas/Debug` scenes, search keywords that are never shown, and the other-language copies of Apple's own App Store words. Those copies are in `base-texts/apple-words/`; their English entries are in the CSV.

## Columns of `copy-inventory.csv`

- `key`: the String Catalog key (`%@`, `%lld`… as the compiler writes them). Otherwise `literal` (hard-coded), `runtime (no key)` (an error message passed through), or `system (AppKit/SwiftUI)`.
- `text`: the English text as written, with placeholders as `{name}`.
- `kind`: one of the requested kinds.
- `file`: `path:line`.
- `view`: area › sub-area › Swift type that shows it or builds it.
- `trigger`: the switch `case`, `if` condition, ternary, or function the text depends on. For App Store Connect errors it gives the HTTP status (401, 403, 404, 409/422, 429, other/5xx, non-HTTP).
- `variables`: each placeholder, its Swift expression and type. The type is integer/decimal from the compiler's format specifier; plural-sensitive, currency, date and percent are inferred.
- `generated`: `yes` for templates with placeholders, text joined at runtime, and runtime error text.
- `should_be_in_catalog`: **YES** for every hard-coded string the person sees that should move to the String Catalog (547: 313 Swift literals, 223 Help-article blocks, 11 from the price index JSON). **CHECK** for 41 hard-coded strings whose type isn't used by any screen or MCP file, so I couldn't confirm they're shown.
- `catalog`: the detailed status (localizable / hard-coded / assistant-only / proper noun / Apple's words / provided by macOS / runtime text).
- `audience`: `person`, `person?` (not confirmed) or `assistant`. Assistant rows are MCP tool titles, descriptions and parameters, MCP replies and refusals, and prompts. It also covers plain text from types that only MCP or prompt code uses, and text that says "the person" or names MCP tools.
- `code_context`: the call and argument label the literal sits in (e.g. `String(localized:) | Banner(title:)`).
- `notes`: comments, "fragment: joined with other text at runtime", "Text(verbatim:)" and similar.

## Caveats

- Texts nested inside another text's interpolation (`"\(n == 1 ? "one" : "many")"`) are their own rows.
- The price index JSON (`PriceIndexSnapshot.json`) has shown edition labels and badges; they are rows too.

- `kind`, `view`, `trigger` and `audience` are inferred from the code around each string: its call, argument label, enclosing type and function, switch case and condition. They are right for most rows but not checked one by one. `text`, `key`, `file`, `variables`, `generated` and `catalog` are exact.
- A key used in several places appears once per place, because each place can need different copy.
- Fragments like "the phones" or "{count} reviews" are pieces of a longer sentence assembled at runtime. The sentence is only complete in the code.
- Apple's own error details (`detail:` from App Store Connect, in English) and system errors (in the Mac's language) are appended at runtime; they are marked in `variables` and `notes`.
- `base-texts/mcp/mcp-tools.json` and `.md` list the 117 MCP tools from source. `{expr}` marks shared text interpolated at runtime; that text is in the copied Swift files next to them.
- Info.plist: the app's plist is generated from build settings and has **no usage descriptions** (no `NS…UsageDescription` keys). `base-texts/info-plist/` has the built `Info.plist` and the build settings.
