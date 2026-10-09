# Development and testing

## Repository layout

- `GrimfallReroll/`: installable addon, including art and licensed fallback fonts.
- `tests/`: mocked game APIs and regression tests; no account data or client code.
- `scripts/`: portable validation and ZIP packaging.
- `docs/images/`: the live in-game screenshot used on the project page and older
  offline layout previews, all excluded from the installable ZIP. See the
  [image provenance notes](images/README.md).
- `dist/`: generated release ZIP, SHA-256 checksum, and per-file manifest (gitignored).

## Run the checks

From the repository root, with PowerShell 7 and Lua 5.1 installed:

```powershell
./scripts/Test.ps1 -LuaCommand lua5.1
./scripts/Build-Package.ps1 -LuaCommand lua5.1
```

If your Lua 5.1 executable is named `lua`, use `-LuaCommand lua` instead.
To run only the mocked Lua suite:

```sh
lua5.1 tests/run.lua
```

Windows PowerShell can also use an already installed MoonSharp 2.0 interpreter:

```powershell
./scripts/Test.ps1 -MoonSharpPath 'C:/path/to/MoonSharp.Interpreter.dll'
./scripts/Build-Package.ps1 -MoonSharpPath 'C:/path/to/MoonSharp.Interpreter.dll'
```

The scripts do not silently install local tools. GitHub Actions uses an explicit
Lua 5.1 installation and runs the same validation/packaging entry point.

## What is checked

- All installable files match the reviewed baseline for the TOC version.
- The original 0.9.1-rc1 baseline remains available for upgrade comparisons.
- No unexpected files enter the addon package.
- Every TOC reference exists; texture dimensions and formats are valid.
- Font headers and required third-party license notices are present.
- The mocked behavior/layout tests cover queues, scroll checks, confirmations,
  per-spec locks, history, tooltips, frame layout, Hide Locked, and chat-only
  results without overlay allocations or expiration redraws.
- Spec-lock regressions cover pre-refresh clicks, stale row/popup contexts,
  missing identity/events, away-and-back switches, bounded recovery, preserved
  saved protections, and ability/talent results across separate spec slots.
- Performance regressions cover bounded build scans, native-animation waits,
  event bursts, unchanged history reuse, and read-only performance reports.
  These work-count checks are not live frame-rate benchmarks.
- The 0.9.3 suite includes display-cache invalidation/bounds, live talent
  rank reads, coroutine slice limits, cancellation on build/spec change,
  incomplete/malformed reads, timeout and synchronous fallback. Partial
  display reads cannot edit entries or authorize native reroll requests.
- All 118 prior regressions remain; the two spec-lock recovery helpers now
  advance read-only frames to completion before checking the completed view.
  Immediate stale-spec invalidation checks remain immediate. Total: 139.
- Every ZIP member has the correct `GrimfallReroll/` prefix and matches its
  per-file SHA-256 hash.

Each version has a frozen baseline fixture. For a runtime change, review the
specific diff before adding its new fixture, version, tests, and release notes.
Do not blindly rewrite expected hashes to make a failing test pass. Update
public download links only when the new release is actually published.

Use `-OutputDirectory dist/0.9.2` when building beside an existing release
so its manifest and checksums are preserved along with its ZIP.
The current release uses `-OutputDirectory dist/0.9.3`.

The repository license and `GrimfallReroll/LICENSE.txt` must stay identical.
The packaged source retains its tested line endings through `.gitattributes`.

## Release process

1. Review the change and run the tests.
2. Check native behavior in the intended Grimfall client where possible, and
   state what was and was not verified.
3. Build in a clean checkout. Packaging refuses to overwrite an existing ZIP.
4. Tag the exact commit and publish user-facing updates as regular releases
   with an unsuffixed version by default, per the maintainer's preference.
   Set the new regular version as Latest and update the main player download
   link after publication. Use pre-releases only if explicitly requested by
   the maintainer. Retain actual validation limits in the notes regardless
   of release status. Do not rewrite earlier releases or tags.
5. Attach the generated named ZIP, `SHA256SUMS.txt`, and `manifest.json`.
6. Verify the uploaded downloads before announcing the release.

The ZIP contains the addon only, not tests, preview assets, tools, private
installation receipts, saved variables, or extracted game files. Tests are
offline; they do not launch WoW or consume reroll scrolls. Artwork source-pixel
comparison and native visual testing are separate from the portable suite.
