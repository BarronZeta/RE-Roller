RE: Roller by Vash 0.9.1-rc1 - Hide Locked filters

NEW IN 0.9.1
- Hide Locked checkbox beside each Abilities / Talents heading.
- Independent, remembered choices for each column; both default to off.
- Filters the current spec's protected entries without unlocking them, changing
  selections, reroll requests, scroll costs, or saved reroll history.
- Works together with search. Counts indicate shown / learned when filtered.
- Turning it off shows protected entries again, with their locks intact.
- If every entry is hidden, an explanatory message tells you how to show them.
- The existing Emblem/Titan layout, dimensions and row space are unchanged.

NEW IN 0.9.0
- Recessed history wells with an inset gold lip, dark inner top/left shadows,
  a restrained lower bevel, and an opaque darker background.
- Centered learned counts, History controls, queued costs and reroll buttons
  share one fixed-width action column on each side. Names stay left-aligned.
- Active Spec displays the current Grimfall custom spec name and chosen icon.
  These are read-only native metadata, refreshed while the window is visible.
  Unavailable or unnamed metadata is labeled honestly, never guessed.
- Hover the icon OR name under From / To in either history panel for that
  specific spell's game tooltip. Legacy records lacking IDs show a text fallback.
- Emblem is used for headings, names, metadata and controls, with consistent
  sizes, a subtle dark shadow and brighter secondary labels.

FONT AVAILABILITY
Emblem is resolved from LibSharedMedia, then the user's installed
Interface\AddOns\VuhDo\Fonts\Emblem.ttf. VuhDo need not be enabled, but that
font file must remain installed. Emblem itself is NOT redistributed in the ZIP.
If Emblem is absent/unloadable, bundled PT Sans keeps all text readable.
This update changes no global game fonts and adds no required addon dependency.

Artwork is now extracted directly from the approved FinalLayout.png.
No replacement AI artwork was generated for this revision.
The guardian, stepped rune lintel, side pillars, corner caps, base medallions,
dice, panel inlays, checkboxes and button surfaces use the original source.
Transparent masking removes the background scenery. Button labels were removed
using clean interior pixels at the same height, retaining original shading.
Source pixels are padded to power-of-two textures, never stretched at export.
The full guardian remains 901 x 111 logical units when history opens/closes.
Plain rail extensions repeat cropped source sections.

Upgrading from 0.8.0 preserves your preferred window size and position.
Older installations still receive the original one-time 840 x 620 layout
migration. History visibility, locks and saved history stay intact.
The built-in fit scales the entire assembly uniformly to stay on the screen.
You may resize after the first open; further opens retain your new dimensions.

Gray-blue panel surfaces, original rounded buttons and title-cased history
headers replace the previous generated substitutes. Current specialization is
read-only: there is no fake class/spec selection menu.
All item and ability icons in the installed addon still come from game APIs.

Open /rr or use the 32px freely movable launcher.
Left-click queues a learned ability/talent. Right-click protects it silently,
replacing its checkbox with a lock. Unlocking asks for confirmation.
Each column has its own reroll button and independent scroll budget:
  Abilities: Scroll of Destiny (640)
  Talents: Scroll of Reshaping (639)
Quick Animation shortens only this addon's reroll presentation.
Pause waits for an in-flight result. Resume continues. Stop or closing the
planner sends no further requests. Late confirmed results are still recorded.

History checkboxes independently open the side panels. Mouse-wheel/scrollbar
browses; Newest returns to the newest record. From / To icons and names each
show their own spell tooltip. Last three transformations wrap in a bounded,
scrollable footer.
History retains 100 confirmed rolls TOTAL per character, across kinds/specs.
Existing data is reused, not reset. Reroll requests and confirmation logic are
unchanged from the installed v0.6.0 (Core.lua and Client.lua are byte-identical).

Folder: GrimfallReroll
Saved variable: GrimfallRerollDB
No other addons or game settings are part of this release.
Legacy Frame/Guardian/Plinth texture files remain for upgrade continuity, but
are not referenced by the new skin.

Fallback typography copyright (c) 2010 ParaType Ltd. Fonts redistributed unmodified
under SIL OFL 1.1; license files are in Fonts/.
https://github.com/google/fonts/tree/main/ofl/ptserif
https://github.com/google/fonts/tree/main/ofl/ptsans

Offline previews are layout diagnostics, not game captures. Their sample icons
are cropped from the reference and are NOT part of the addon package.
Final native rendering still requires in-game visual verification.
