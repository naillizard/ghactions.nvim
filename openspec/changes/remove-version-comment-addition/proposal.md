## Why
When updating GitHub Actions versions to commit SHAs, a comment with the tag name is automatically appended to the line (e.g., ` # v1.2.3`). This creates visual clutter and is unnecessary since users can check the version separately if needed.

## What Changes
- Remove automatic comment addition when updating actions to SHA versions
- Simplify the `update_action_in_file` function by removing comment logic

## Impact
- Affected specs: telescope-integration
- Affected code: lua/ghactions/telescope/pickers.lua:344-349
