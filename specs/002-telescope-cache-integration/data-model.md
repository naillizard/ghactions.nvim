# Data Model: GitHub Actions Plugin

**Created**: 2025-10-23  
**Purpose**: Define data entities and relationships for the GitHub Actions plugin

## Core Entities

### Action Reference

Represents a GitHub Action used in a workflow file.

**Fields**:
- `owner` (string): Repository owner (e.g., "actions")
- `repo` (string): Repository name (e.g., "checkout")
- `version` (string): Current version tag or SHA (e.g., "v4" or "sha123...")
- `line_number` (number): Line number in workflow file
- `file_path` (string): Path to workflow file
- `type` (enum): "tag" | "sha"

**Validation Rules**:
- owner and repo must match pattern: `^[a-zA-Z0-9._-]+$`
- version must be valid Git tag or 40-character SHA
- file_path must match `.github/workflows/*.yml|yaml`

**State Transitions**:
- tag → sha (pin operation)
- sha → tag (unpin operation)

### Release Information

Contains GitHub release data for an action.

**Fields**:
- `owner` (string): Repository owner
- `repo` (string): Repository name
- `tag_name` (string): Release tag (e.g., "v4")
- `sha` (string): Commit SHA for this tag
- `name` (string): Release name
- `body` (string): Release description
- `published_at` (string): ISO 8601 timestamp
- `prerelease` (boolean): Whether this is a prerelease

**Validation Rules**:
- tag_name must follow semantic versioning
- sha must be valid 40-character Git SHA
- published_at must be valid ISO 8601 date

### Cache Entry

Represents cached data with TTL.

**Fields**:
- `key` (string): Cache key (e.g., "actions_checkout")
- `data` (object): Cached data (Release Information or README content)
- `timestamp` (number): Unix timestamp when cached
- `ttl` (number): Time to live in seconds
- `etag` (string): HTTP ETag for cache validation

**Validation Rules**:
- key must be non-empty string
- timestamp must be valid Unix timestamp
- ttl must be positive integer

### Workflow File

Represents a GitHub Actions workflow file.

**Fields**:
- `path` (string): File path
- `content` (string): File content
- `actions` (array): Array of Action References
- `last_modified` (number): File modification timestamp

**Validation Rules**:
- path must match `.github/workflows/*.yml|yaml`
- content must be valid YAML
- actions array contains valid Action References

### Picker Entry

Represents an entry in the Telescope picker.

**Fields**:
- `display_name` (string): "owner/repo"
- `value` (object): Action Reference or Release Information
- `ordinal` (string): Searchable text
- `preview_content` (string): README or release notes
- `metadata` (object): Additional picker metadata

**Validation Rules**:
- display_name must be "owner/repo" format
- preview_content must be non-empty string

## Relationships

```
Workflow File 1..* Action Reference
Action Reference 1..1 Release Information
Release Information 0..* Cache Entry
Picker Entry 1..1 Action Reference
```

## Data Flow

1. **File Detection**: Scan workflow files → Extract Action References
2. **Cache Lookup**: Use Action Reference → Check Cache Entry
3. **API Fetch**: If cache miss/stale → Fetch Release Information
4. **Cache Update**: Store Release Information → Create Cache Entry
5. **Picker Display**: Transform Release Information → Create Picker Entry
6. **User Selection**: User selects Picker Entry → Update Action Reference

## Cache Key Strategy

**Action Cache**: `{owner}_{repo}` (e.g., "actions_checkout")
**Release Cache**: `{owner}_{repo}_releases` (e.g., "actions_checkout_releases")
**README Cache**: `{owner}_{repo}_readme` (e.g., "actions_checkout_readme")

## File Format Examples

### Action Reference (in workflow file)
```yaml
uses: actions/checkout@v4
```

### Cache Entry (JSON)
```json
{
  "key": "actions_checkout",
  "data": {
    "owner": "actions",
    "repo": "checkout",
    "releases": [
      {
        "tag_name": "v4",
        "sha": "1234567890abcdef...",
        "name": "v4.0.0",
        "published_at": "2023-09-15T12:00:00Z"
      }
    ]
  },
  "timestamp": 1698765432,
  "ttl": 3600
}
```

### Picker Entry (Telescope)
```lua
{
  display_name = "actions/checkout",
  value = { owner = "actions", repo = "checkout", current_version = "v4" },
  ordinal = "actions/checkout v4 checkout",
  preview_content = "# GitHub Checkout Action\n\nThis action checks out...",
  metadata = { type = "action", cache_hit = true }
}
```

## Error States

### Invalid Action Reference
- Pattern doesn't match `uses: owner/repo@version`
- Owner or repo contains invalid characters
- Version is neither valid tag nor SHA

### Cache Errors
- Cache file corrupted (invalid JSON)
- Cache permission denied
- Cache directory doesn't exist

### API Errors
- Rate limit exceeded
- Repository not found
- Network connectivity issues

## Performance Considerations

### Cache Optimization
- Use file modification time for cache invalidation
- Implement LRU eviction for cache size management
- Compress large cache entries

### Memory Management
- Lazy load picker entries
- Limit preview content size
- Clean up unused cache entries

### Concurrency
- File locking for cache updates
- Async API calls with cancellation
- Debounced cache refresh