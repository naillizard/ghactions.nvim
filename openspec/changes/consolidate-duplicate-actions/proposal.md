## Why
When using `:GhActionsVersions`, duplicate actions in the same file create visual clutter and make it harder to scan for updates. Users need to see consolidated information with all line locations where the same action is used.

## What Changes
- Consolidate duplicate actions in the telescope picker display
- Show concatenated line numbers (e.g., "14,23,31") instead of separate entries
- Apply version updates to all occurrences when selecting a consolidated action
- Maintain existing behavior for single-use actions

## Impact
- Affected specs: telescope-integration
- Affected code: lua/ghactions/telescope/pickers.lua, lua/ghactions/github/versions.lua