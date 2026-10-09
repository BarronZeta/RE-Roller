RE: Roller by Vash 0.9.4 - Startup and diagnostic fixes

NEW IN 0.9.4
- Start the first roll using one complete fresh synchronous build read instead
  of two immediate reads. Reuse is restricted to the same startup call stack,
  with unchanged build epoch, spec and current snapshot. Changed context triggers
  a fresh read. Animation waits and pauses never keep the shortcut for later.
- Later rolls and every result confirmation still read the complete build.
  Combat, death, locks, scroll counts, exact results and no-retry guards remain.
- Clear the stuck "Reading build across frames..." message when a same-spec
  display scan finishes. Preserve unrelated stop/error/result messages.
- Unknown commands (including /rr pref) now show help without closing the
  window or stopping rolls. Use /rr help; command case and extra spaces work.
- /rr perf prints the report IN CHAT; /rr perf reset clears timing counters.
  The report now counts same-action startup reads reused.
- All 158 offline Lua 5.1 regressions pass. A normal four-roll queue uses eight
  full validation reads instead of nine, excluding display refreshes. A native
  ability-list call may still hitch; this is not a guarantee of improved FPS.
- Your saved settings, per-spec locks, history and the interface are unchanged.

NEW IN 0.9.3
- Read-only window opening, Refresh and idle build updates read the full build
  across frames. Partial reads never become selectable or authorize a reroll.
- Refresh slices target 4 ms, with call/node bounds when timing is unavailable.
  A single native game API cannot be interrupted and can exceed that target.
- Display-only spell names/rank text/icons use a bounded session cache. Known
  abilities, current talent ranks, spec, locks and scroll counts stay live.
- Build/spec events cancel outdated reads and invalidate display metadata.
  Closing or stopping cancels the read-only job; a 30-second deadline prevents
  a job staying open forever. A synchronous manual fallback is available.
- Redundant idle reads after a validated result and unchanged row/icon/style
  updates are reduced. Artwork, fonts and native animation callbacks are intact.
- Full pre-request and post-result validation remains synchronous. This may
  still cause a hitch on clients with slow native talent-tree APIs; safety and
  confirmation checks have not been weakened to claim a speed improvement.
- /rr perf now separates read work, refresh slices, wall time, native API costs
  and display-cache hits. /rr perf reset starts a clean measurement.
- /rr smooth off (or on) changes only the current session's display refresh
  mode. /rr refresh sync performs one full read when no reroll is outstanding.
- Existing saved-data schema, settings, per-spec locks and history are retained.
- All 139 mocked Lua 5.1 regressions pass, including all 118 prior checks and
  21 new optimization/safety checks. Golden old/new snapshots match. Simulated
  API-cost benchmarks are not live FPS measurements or proof a hitch is fixed.
- Published as a regular release. This changes the version label and release
  status, not the validated rc1 gameplay logic. See PERFORMANCE-TEST.txt for
  safe diagnostic steps and the remaining native-call limitations.

NEW IN 0.9.2-rc5
- Lock, unlock and selection clicks verify the live active spec before editing.
  An old or unavailable spec view rejects the click and schedules a refresh.
- Unlock popups expire on a spec switch, including switching away and back.
  Ordinary refreshes within the same spec preserve a valid confirmation.
- Rejects clicks on stale row objects. A lightweight spec-index check catches
  missed native switch events without rescanning a stable ability/talent build.
- Existing per-spec locks, settings, history and saved-data schema are untouched.
  A talent already saved as locked on both specs remains locked on both specs.
  To remove an unwanted lock, activate that spec, Refresh, uncheck Hide Locked
  if needed, then right-click the entry and confirm Unlock.
- Chat-only notifications, artwork, scroll checks and native callbacks remain.
- All 118 mocked Lua 5.1 regressions pass, including 21 spec-lock cases. Live
  Grimfall confirmation is still required; no real scrolls are used by tests.

NEW IN 0.9.2-rc4
- Removes the floating roll-announcement text above the interface entirely,
  including its frame, notice queue, text measurement, and per-frame fade work.
- Confirmed rolls still send one chat message with old/new names, icons and
  the scroll cost. Unconfirmed or duplicate result events do not add messages.
- Removes the temporary recent-result highlight and its delayed full redraw.
  Recent Transformations and both scrollable history panels remain available.
- Preserves Stone Titan graphics, fonts, per-spec locks, Hide Locked settings,
  saved history, reroll confirmation checks and native animation callbacks.
- All 97 mocked Lua 5.1 regressions pass. This removes known UI work, but does
  not prove the overlay caused all stutter; live FPS still needs a game test.

NEW IN 0.9.2-rc3
- Waits for the result event and matching scroll consumption before reading
  the full build. Incomplete post-result builds retry at most once per second.
- Does not rescan all talent trees while native presentation is still active.
- Ordinary bag updates refresh counts, not the full build. Unrelated idle
  error messages no longer trigger scans; actual build events are coalesced.
- Reuses unchanged history rows and avoids duplicate renders per result.
- Adds /rr performance (or /rr perf): read-only work timings and frame-gap
  counters. Frame gaps include the whole client, not only this addon.
- Every request still gets a fresh complete build/spec/lock check. Every
  result still requires one replacement and exactly one matching scroll.
- Stone Titan artwork, default font, text-only notices, saved locks and
  history are preserved. No native animation callbacks are removed or skipped.
- Offline Lua 5.1 regressions pass; in-game FPS improvement is not yet measured.

NEW IN 0.9.2-rc2
- Uses WoW's included Friz Quadrata font throughout the planner. No Emblem,
  VuhDo font paths or LibSharedMedia font lookups are used.
- The floating notice shows only old -> new text and spell icons. No black
  background, border, heading or decorative divider remains.
- A thin outline and shadow keep results readable over the game world.
- Result colors, wrapping, fading and one-at-a-time presentation are retained.
- Reroll timing, history, locks, filters, artwork and window settings are unchanged.

NEW IN 0.9.2
- Restored the fading result notice above/in front of the planner, with both
  spell icons and clear old -> new text (font updated in rc2 above).
- Ability results use gold; talent results use violet. Long names wrap inside
  an automatically sized, click-through notice kept on screen.
- Rapid confirmed results are announced one at a time, independently of the
  reroll queue. Reading/fading a notice never holds up another reroll.
- Closing the planner clears visible/queued notices. Late confirmed results
  still go to chat and saved history without reopening the planner.
- Recent Transformations and both history panels remain available as before.
- No changes to artwork, protection locks, saved settings or reroll requests.

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
The current build uses Fonts\FRIZQT__.TTF, included with WoW. If that font
cannot load, bundled PT Sans is the fallback. No external font addon is needed.
RE: Roller no longer requests Emblem or reads font paths from other addons.
Other addons and their font files are not changed or removed by this update.
No global game fonts are changed.

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
Existing data is reused, not reset. Queue work is scheduled more efficiently
in rc3; fresh pre-request checks and complete result validation remain required.

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
