# Feature Specification: Telescope Integration with Smart Caching

**Feature Branch**: `002-telescope-cache-integration`  
**Created**: 2025-10-23  
**Status**: Draft  
**Input**: User description: "To add to that, when the Telescope picker is invoked with :GhActionsVersions, for each action used in the current workflow file, that is a file under .github/workflows/*.yml|yaml, we first try the cache to locate any actions that are already cached to avoid making unescessary api calls, if there's no cache for a particular action or the cache is stale, the api calls are made to stale or not found actions. The information is then transformed to display in a friendly way in Telescope, for example, for a given file one might have `uses: actions/checkout@v4` or `uses: actions/checkout@sha`, in both cases we need to resolve the github release and display in Telescope. On the left hand side "the picker side" the name of the action in `owner/repo`, ideally a design where the user can view the recent 2 releases of each action and allow the user to preview the readme file on Telescope's preview "right side", the user can move up and down and the preview updates accordingly, if the user hits enter to select the entry, it updates the sha on the `uses: owner/repo@<sha>` file."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Interactive Version Selection with Telescope (Priority: P1)

As a developer working with GitHub Actions workflows, I want to use an interactive Telescope picker to browse and select action versions so that I can visually compare releases and preview documentation before making changes.

**Why this priority**: This is the core enhanced functionality that significantly improves user experience by providing visual selection with preview capabilities, making the plugin much more user-friendly and informative.

**Independent Test**: Can be fully tested by opening a workflow file, invoking the Telescope picker, navigating through options, and verifying that the preview updates and selection works correctly.

**Acceptance Scenarios**:

1. **Given** a workflow file contains `uses: actions/checkout@v4`, **When** I run `:GhActionsVersions`, **Then** Telescope opens showing `actions/checkout` with recent releases
2. **Given** the Telescope picker is open, **When** I navigate between entries, **Then** the preview pane updates to show the corresponding README file
3. **Given** I select a release from the picker, **When** I press Enter, **Then** the workflow file is updated with the selected version's SHA
4. **Given** a workflow file contains `uses: actions/checkout@sha`, **When** I run `:GhActionsVersions`, **Then** Telescope shows the current SHA and available releases

---

### User Story 2 - Smart Cache Management (Priority: P1)

As a developer, I want the plugin to use intelligent caching so that version information loads instantly and API calls are minimized, ensuring fast performance even with limited network connectivity.

**Why this priority**: Caching is critical for performance and user experience, reducing API calls by 90% and enabling offline functionality for frequently used actions.

**Independent Test**: Can be fully tested by running the picker multiple times and verifying that cached data is used initially, then API calls are made only for stale or missing cache entries.

**Acceptance Scenarios**:

1. **Given** I have previously viewed action versions, **When** I run `:GhActionsVersions` again, **Then** the picker opens instantly using cached data
2. **Given** cache is stale for an action, **When** I run `:GhActionsVersions`, **Then** API calls are made only for stale entries while others use cache
3. **Given** no cache exists for an action, **When** I run `:GhActionsVersions`, **Then** API calls are made to fetch the missing information
4. **Given** I am offline, **When** I run `:GhActionsVersions`, **Then** the picker works with cached data and shows offline status

---

### User Story 3 - Workflow File Discovery (Priority: P2)

As a developer, I want the plugin to automatically discover all actions used in my current workflow files so that I can manage versions without manually specifying each action.

**Why this priority**: Automatic discovery makes the plugin more convenient and reduces user friction, especially in complex workflows with many actions.

**Independent Test**: Can be fully tested by creating workflow files with multiple actions and verifying that all are discovered and displayed in the picker.

**Acceptance Scenarios**:

1. **Given** a workflow file contains multiple action references, **When** I run `:GhActionsVersions`, **Then** all actions from the file are discovered and available in the picker
2. **Given** I have multiple workflow files, **When** I run `:GhActionsVersions` from a specific file, **Then** only actions from that file are discovered
3. **Given** workflow files use both tags and SHAs, **When** I run `:GhActionsVersions`, **Then** both types are correctly identified and processed
4. **Given** a workflow file has malformed action references, **When** I run `:GhActionsVersions`, **Then** valid actions are discovered and invalid ones are ignored with warning

---

### User Story 4 - Release Information Display (Priority: P2)

As a developer, I want to see detailed release information including the most recent releases and README content so that I can make informed decisions about which version to use.

**Why this priority**: Providing rich information helps users understand what changes are available and choose the most appropriate version for their needs.

**Independent Test**: Can be fully tested by verifying that the picker displays the correct number of recent releases and that the preview shows the correct README content.

**Acceptance Scenarios**:

1. **Given** an action has multiple releases, **When** I view it in the picker, **Then** the most recent 2 releases are displayed
2. **Given** I select an action in the picker, **When** the preview is shown, **Then** the README content is displayed correctly
3. **Given** an action has no README, **When** I view it in the picker, **Then** a helpful message is shown in the preview
4. **Given** release information includes dates and descriptions, **When** I view releases, **Then** this information is clearly displayed

---

### Edge Cases

- What happens when GitHub API rate limits are exceeded during cache refresh?
- How does system handle private repositories that require authentication?
- What happens when an action has been deleted or renamed?
- How does system handle network connectivity issues during API calls?
- What happens when workflow files contain duplicate action references?
- How does system handle malformed YAML files in .github/workflows/?
- What happens when cache files become corrupted or unreadable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST scan `.github/workflows/*.yml|yaml` files for action references using pattern `uses: owner/repo@version`
- **FR-002**: System MUST implement cache-first strategy, checking local cache before making API calls
- **FR-003**: System MUST detect stale cache entries and refresh them via GitHub API
- **FR-004**: System MUST display action information in Telescope picker with `owner/repo` format
- **FR-005**: System MUST show the most recent 2 releases for each action in the picker
- **FR-006**: System MUST provide README preview functionality in Telescope's preview pane
- **FR-007**: System MUST update preview content in real-time as user navigates picker entries
- **FR-008**: System MUST replace action version with selected SHA when user makes selection
- **FR-009**: System MUST handle both tag-based and SHA-based action references
- **FR-010**: System MUST resolve GitHub release information for both tags and SHAs
- **FR-011**: System MUST provide offline capability using cached data when network unavailable
- **FR-012**: System MUST implement cache TTL with reasonable expiration periods
- **FR-013**: System MUST handle GitHub API rate limits gracefully with user feedback
- **FR-014**: System MUST validate workflow file syntax before making modifications
- **FR-015**: System MUST provide clear error messages for authentication and network issues

### Quality Requirements

- **QR-001**: Code MUST pass stylua formatting and luacheck linting
- **QR-002**: All features MUST have unit tests with ≥80% coverage
- **QR-003**: UI interactions MUST complete in under 100ms
- **QR-004**: API calls MUST complete in under 500ms
- **QR-005**: Error messages MUST be actionable and user-friendly

### User Experience Requirements

- **UX-001**: Interface MUST follow consistent Telescope design patterns
- **UX-002**: All operations MUST provide clear feedback through notifications
- **UX-003**: Configuration MUST have sensible defaults with clear documentation
- **UX-004**: Progress MUST be shown for operations >2s
- **UX-005**: All user-facing changes MUST include migration guide
- **UX-006**: Telescope picker MUST open in under 200ms for cached data
- **UX-007**: Preview content MUST update in under 100ms when navigating
- **UX-008**: Offline status MUST be clearly indicated when applicable

### Performance Requirements

- **PF-001**: Plugin startup MUST add <10MB memory usage
- **PF-002**: Peak memory usage MUST stay <50MB during operations
- **PF-003**: File operations MUST complete in under 2s
- **PF-004**: Performance regressions MUST be caught in CI/CD
- **PF-005**: Resource-intensive operations MUST be cancellable
- **PF-006**: Cache hit rate MUST be ≥90% for frequently used actions
- **PF-007**: API call reduction MUST achieve 10x fewer requests compared to no caching
- **PF-008**: Cache storage MUST not exceed 100MB for typical usage

### Key Entities *(include if feature involves data)*

- **Workflow File**: YAML file in `.github/workflows/` containing GitHub Actions definitions
- **Action Reference**: Line in workflow file using pattern `uses: owner/repo@version`
- **Cache Entry**: Local storage of action version information with TTL and metadata
- **Release Information**: GitHub release data including version, date, and description
- **Preview Content**: README file content and documentation for display
- **Picker Entry**: Telescope picker item representing an action with its versions
- **Cache Manager**: Component handling cache storage, retrieval, and invalidation
- **API Client**: Component for GitHub API communication with rate limiting

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open the version picker in under 200ms for cached actions
- **SC-002**: Cache hit rate achieves ≥90% for frequently used actions
- **SC-003**: Preview content updates in under 100ms when navigating between actions
- **SC-004**: Plugin reduces GitHub API calls by 90% compared to uncached approach
- **SC-005**: Users report 85% satisfaction with the interactive selection experience
- **SC-006**: Plugin works offline for cached actions with 95% success rate
- **SC-007**: Users can complete version selection tasks 60% faster than manual methods