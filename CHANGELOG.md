# Changelog

## 0.9.2-rc3 - 2026-10-07

Public pre-release focused on reducing work during rerolls and adding read-only
performance diagnostics. In-game FPS improvement has not yet been measured.

### Changed

- Wait for the result event and matching scroll consumption before reading the
  full build. Retry incomplete post-result builds at most once per second.
- Avoid scanning all talent trees while waiting for native roll presentation.
- Refresh inventory counts instead of the full build for ordinary bag updates.
  Unrelated idle error messages no longer trigger scans; actual build-change
  events are coalesced.
- Reuse unchanged history rows, skip unchanged status redraws, and perform one
  final redraw per confirmed result.
- Add `/rr performance` and `/rr perf` for session snapshot/render call counts,
  average and maximum work timings, and frame-gap counters while rolling.
  Frame gaps include the whole client, not just RE: Roller.

### Preserved

- Fresh complete build, specialization, and lock checks before every request.
- Result validation still requires one replacement and exactly one matching
  scroll consumed; uncertain results stop the queue without an automatic retry.
- Stone Titan artwork, built-in font, text-only result notices, saved locks,
  history, and native animation callbacks.

### Validation

- Added seven performance/safety regression tests, bringing the mocked Lua 5.1
  suite to 97 checks. Tests never connect to the game or consume scrolls.
- All 37 installable files match the reviewed rc3 build installed for local
  testing. Live frame-rate and client behavior still need in-game confirmation.

## 0.9.2-rc2 - 2026-10-06

Public pre-release. Includes the notification restoration from the private rc1
build below, with the rc2 built-in typography and text-only styling.

### Changed

- Replaced Emblem with WoW's included Friz Quadrata throughout the planner.
  Removed shared-media and VuhDo font discovery; bundled PT Sans remains the
  fallback if the built-in font cannot load.
- Removed the floating result notice's background, border, heading and divider.
  Only centered old-to-new spell text and icons remain, with a thin outline
  and shadow for readability over the game world.
- Preserved notice ordering, wrapping, fading, screen clamping, and independence
  from reroll timing. Artwork, saved data, and reroll behavior are unchanged.
- Added tests that reject a notice background/decoration and verify built-in
  font selection, outline flags, and fallback without consulting other addons.

## 0.9.2-rc1 - private development build

### Fixed

- Restored the fading reroll result notice above/in front of the planner. The
  previous layout revision had removed it, leaving chat and footer results only.
- Confirmed results display one at a time, with spell icons, centered Emblem or
  fallback text, and gold ability / violet talent accents.
- Long names wrap inside an automatically measured notice. Foreground layering
  and screen clamping keep the notice visible, including near the screen edge.
- Notification timing is independent of reroll timing. Closing the planner
  clears pending notices; late confirmations still save to chat and history.

### Validation

- Added regression coverage for ordered bursts, fade/reuse, wrapping/resizing,
  hidden results, Quick Animation off, and separation from real reroll state.
- No artwork, font assets, lock schema, saved settings, or request/confirmation
  logic changed. Native game rendering still needs an in-game visual check.

## 0.9.1-rc1 - 2026-10-06

First public GitHub release of RE: Roller by Vash.

### Added

- Independent **Hide Locked** switches for Abilities and Talents, remembered between sessions.
- Filtered shown/learned counts, search compatibility, and explanatory empty states.
- Public installation and usage guide, issue templates, portable tests, and packaging instructions.
- MIT license for original code and documentation, with third-party font notices preserved.

### Preserved

- Current-specialization protection locks, learned entries, selections, scroll costs, and confirmed history.
- Titan Reliquary artwork, Emblem support and bundled font fallback, existing layout dimensions and positions.
- Existing reroll request and result-confirmation logic.

The public ZIP adds license/notice files. Its six runtime Lua files, TOC,
artwork, fonts and original README match the existing 0.9.1-rc1 source baseline.
No game installation, saved variables, or other addons are changed by publishing.

## 0.9.0 - private development build

- Recessed history panels with inset gold edging and opaque backgrounds.
- Aligned action columns and centered control labels.
- Current Grimfall specialization name and icon.
- Separate From/To history tooltips.
- Emblem typography with a bundled PT Sans fallback.

## Earlier private development

- Side-by-side learned Abilities and Talents, independent reroll buttons, and spec-specific protection locks.
- Confirmed queues with Pause/Resume, Stop, Quick Animation, and scroll budgeting.
- Movable launcher, resizable planner, scrollable history panels, and bounded recent announcements.
- Titan Reliquary skin derived from the approved visual reference.

Earlier local iteration folders and personal installation backups are not
published as separate public releases.
