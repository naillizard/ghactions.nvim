# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ghactions.nvim** is a Neovim plugin for GitHub Actions version management. It provides interactive browsing/updating of action versions via Telescope, pinning actions to commit SHAs for security, and smart caching of GitHub API responses. Requires Neovim >= 0.7.0, plenary.nvim, telescope.nvim, and the GitHub CLI (`gh`).

## Commands

```bash
# Format code
stylua lua/

# Check formatting
stylua --check lua/

# Run tests (from repo root)
nvim -u tests/minimal_test.lua +lua -c "lua require('tests.minimal_test').run_all()"

# Health check (inside Neovim)
:checkhealth ghactions
```

## Architecture

### Module Structure

- **`lua/ghactions/init.lua`** — Plugin entry point: command registration, keymap setup, config merging
- **`lua/ghactions/github/client.lua`** — GitHub API client wrapping `gh api` CLI with retry/rate-limit handling
- **`lua/ghactions/github/versions.lua`** — Core logic (~760 lines): version parsing, comparison, SHA resolution, update detection, duplicate consolidation
- **`lua/ghactions/cache/`** — Multi-layer caching (memory + persistent) with TTL-based expiration
- **`lua/ghactions/telescope/`** — Two-level Telescope picker (actions → versions) with custom entry display and preview
- **`lua/ghactions/secure_all.lua`** — Batch secure/unsecure operations across all actions in a buffer
- **`lua/ghactions/config/init.lua`** — Centralized config with dot-notation access (`config.get("github.api_timeout")`)
- **`lua/ghactions/utils/health.lua`** — Dependency validation for `:checkhealth`
- **`plugin/ghactions.lua`** — Load guard

### Key Design Decisions

- **Version resolution**: Releases pin to commit SHAs (reproducibility), tags use tag names (readability)
- **API access**: Uses `gh` CLI rather than direct HTTP — handles authentication and private repos automatically
- **Secure/unsecure flow**: `:GhActionsSecure` pins to a SHA and adds a trailing comment with the original tag so `:GhActionsUnsecure` can restore it. Regular version updates (Telescope picker, `:GhActionsVersions`) do **not** add comments
- **Duplicate consolidation**: Actions appearing multiple times in a workflow are grouped by name with line number tracking

### Patterns

- All modules use `local M = {} ... return M`
- Error handling: `pcall()` + `vim.notify()` with severity levels
- Async operations use plenary's async library
- GitHub client has exponential backoff retry logic

## Code Style

Enforced by stylua (`.stylua.toml`): 2-space indentation, 120 column width, double quotes. Use conventional commits with semantic versioning.

## OpenSpec Workflow

The project uses OpenSpec for spec-driven development. Change proposals go in `openspec/changes/`. See `openspec/AGENTS.md` for the three-stage workflow: create proposals → implement → archive.
