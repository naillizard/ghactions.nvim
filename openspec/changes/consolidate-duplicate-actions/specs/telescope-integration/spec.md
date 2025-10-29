## MODIFIED Requirements

### Requirement: Action List Display
The system SHALL consolidate duplicate GitHub Actions in the telescope picker display, showing a single entry per action with concatenated line numbers.

#### Scenario: Multiple occurrences of same action
- **WHEN** a workflow file contains the same action on multiple lines (e.g., lines 14, 23, 31)
- **THEN** the telescope picker SHALL display a single entry for that action
- **AND** the line number column SHALL show "14,23,31" instead of separate entries

#### Scenario: Single occurrence of action
- **WHEN** a workflow file contains an action on only one line
- **THEN** the telescope picker SHALL display the entry with the single line number
- **AND** the behavior SHALL be identical to current implementation

### Requirement: Bulk Version Updates
The system SHALL apply version updates to all occurrences of a consolidated action when a new version is selected.

#### Scenario: User selects new version for consolidated action
- **WHEN** user selects a new version for an action that appears on multiple lines
- **THEN** the system SHALL update all occurrences of that action with the same version/SHA
- **AND** the system SHALL preserve the original formatting and comment structure for each line

#### Scenario: Quick update for consolidated action
- **WHEN** user presses Ctrl+U on a consolidated action entry
- **THEN** the system SHALL update all occurrences to the latest version
- **AND** the system SHALL show a notification indicating how many lines were updated

### Requirement: Status Determination
The system SHALL determine update status based on the most recent version used among all occurrences of the same action.

#### Scenario: Mixed versions across occurrences
- **WHEN** the same action appears with different versions across multiple lines
- **THEN** the system SHALL use the most recent version to determine update status
- **AND** the system SHALL display the current version from the first occurrence