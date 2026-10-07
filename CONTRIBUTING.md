# Contributing to RE: Roller

Thanks for helping improve the Grimfall reroll planner.

## Report a problem

Use the bug-report form and include the addon version, Grimfall client/build
information if known, exact reproduction steps, and the planner's status or Lua
error. A cropped screenshot is useful. Never attach account credentials, whole
saved-variable files, private chat logs, or a game installation.

## Suggest an improvement

Use the feature-request form. Explain the player problem and the behavior you
would prefer. Significant layout or reroll-flow changes should be discussed
before implementation.

## Code changes

- Keep runtime code compatible with WoW 3.3.5a's Lua 5.1 environment.
- Do not rename `GrimfallReroll` or the `GrimfallRerollDB` saved variable.
- Preserve character/spec lock isolation and existing saved history.
- Never bypass a missing result confirmation, protection lock, or scroll check.
- Keep Quick Animation separate from server confirmation.
- Add regression tests for changes and run the checks in
  [Development and testing](docs/DEVELOPMENT.md).
- Label offline previews honestly; native game rendering needs a separate check.
- Do not add authentication keys, game files, or account-specific data.

Original code contributions are under the repository's MIT license. Preserve
third-party notices and identify the source/license of any new dependency or asset.
