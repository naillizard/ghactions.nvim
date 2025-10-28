# Project Context

## Purpose
GitHub Actions version management plugin for Neovim with Telescope integration and smart caching. Provides interactive version selection, security pinning to commit SHAs, and workflow management capabilities for GitHub Actions.

## Tech Stack
- **Lua 5.1+** (Neovim compatibility)
- **Neovim >= 0.7.0** - Primary runtime environment
- **plenary.nvim** - Utility library for async operations, HTTP requests, and testing
- **telescope.nvim** - Fuzzy finder UI for interactive selection
- **GitHub CLI (gh)** - Command-line tool for GitHub API interactions

## Project Conventions

### Code Style
- **Stylua** configuration: 2-space indentation, 120 character column width, double quotes preferred
- **Lua patterns**: Use `local M = {}` module pattern, prefer explicit returns
- **Naming**: snake_case for variables/functions, PascalCase for modules
- **Error handling**: Use `pcall` with user notifications via `vim.notify()`
- **Async operations**: Use plenary's async library for GitHub API calls

### Architecture Patterns
- **Modular structure**: Separate concerns into distinct modules (cache, github, telescope, utils)
- **Configuration management**: Centralized config with defaults and user overrides
- **Plugin integration**: Telescope extension pattern with lazy loading
- **Command system**: User commands with validation and error handling
- **Health checks**: Built-in dependency verification and status reporting

### Testing Strategy
- **Minimal test runner**: Custom test framework in `tests/minimal_test.lua`
- **Integration tests**: Workflow file testing with real GitHub Actions
- **Health checks**: Runtime dependency verification via `:checkhealth ghactions`
- **Manual testing**: Interactive testing through Telescope UI

### Git Workflow
- **Feature branches**: Use descriptive branch names for new features
- **Commit messages**: Conventional commits with clear descriptions
- **PR reviews**: Code review required for all changes
- **Release tagging**: Semantic versioning for plugin releases

## Domain Context

### GitHub Actions Ecosystem
- **Actions**: Reusable workflow steps hosted on GitHub
- **Versioning**: Tags (readable) vs commit SHAs (secure)
- **Security**: Pinning to specific commits prevents supply chain attacks
- **Workflows**: YAML files defining CI/CD pipelines

### Neovim Plugin Architecture
- **Plugin loading**: Lazy loading support with proper dependency management
- **User commands**: Vim commands for plugin functionality
- **Key mappings**: Filetype-scoped mappings for YAML/YML files
- **Telescope integration**: Custom pickers and previewers

## Important Constraints
- **Neovim compatibility**: Must work with Neovim 0.7.0+ (Lua 5.1)
- **GitHub API rate limits**: Implement caching and respect rate limits
- **Security**: Never expose tokens or sensitive data in logs
- **Performance**: Efficient caching with TTL and size limits
- **Error resilience**: Graceful handling of network failures and API errors

## External Dependencies

### Required Dependencies
- **GitHub API**: For fetching action versions and release information
- **GitHub CLI (gh)**: For authenticated API calls and private repo access
- **Telescope.nvim**: UI framework for interactive selection
- **Plenary.nvim**: HTTP client, async operations, and utilities

### Optional Dependencies
- **Different plugin managers**: Support for packer.nvim, lazy.nvim, etc.
- **External cache storage**: Future support for persistent caching

### API Integration
- **GitHub REST API**: Releases, tags, and commit information
- **GraphQL API**: For complex queries and batch operations
- **Rate limiting**: Respect GitHub's API limits with exponential backoff
