# Development and testing

## Repository layout

- `GrimfallReroll/`: installable addon, including art and licensed fallback fonts.
- `tests/`: mocked game APIs and regression tests; no account data or client code.
- `scripts/`: portable validation and ZIP packaging.
- `docs/images/`: offline layout previews, excluded from the installable ZIP.
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

- All 35 original 0.9.1-rc1 package files match the existing tested baseline.
- The only additional installable files are the MIT license and asset notices.
- No unexpected files enter the addon package.
- Every TOC reference exists; texture dimensions and formats are valid.
- Font headers and required third-party license notices are present.
- The existing 77 mocked behavior/layout tests cover queues, scroll checks,
  confirmations, per-spec locks, history, tooltips, frame layout and Hide Locked.
- Every ZIP member has the correct `GrimfallReroll/` prefix and matches its
  per-file SHA-256 hash.

The baseline fixture is deliberately frozen for the first public release.
For a future runtime change, review and update the baseline, version, tests,
release notes and download links together. Do not blindly rewrite expected
hashes to make a failing test pass.

The repository license and `GrimfallReroll/LICENSE.txt` must stay identical.
The packaged source retains its tested line endings through `.gitattributes`.

## Release process

1. Review the change and run the tests.
2. Check native behavior in the intended Grimfall client where possible, and
   state what was and was not verified.
3. Build in a clean checkout. Packaging refuses to overwrite an existing ZIP.
4. Tag the exact commit and prepare a GitHub release. Keep release candidates
   marked as pre-releases.
5. Attach the generated named ZIP, `SHA256SUMS.txt`, and `manifest.json`.
6. Verify the uploaded downloads before announcing the release.

The ZIP contains the addon only, not tests, preview assets, tools, private
installation receipts, saved variables, or extracted game files. Tests are
offline; they do not launch WoW or consume reroll scrolls. Artwork source-pixel
comparison and native visual testing are separate from the portable suite.
