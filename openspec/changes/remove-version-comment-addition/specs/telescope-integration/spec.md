## MODIFIED Requirements
### Requirement: Version Update Display and Formatting
The system SHALL update the action version in the workflow file without adding comments to tag names.

#### Scenario: Update to SHA version without comment
- **WHEN** a user selects a SHA version for an action
- **THEN** the action line is updated to use the SHA
- **AND** no comment is appended to the line

#### Scenario: Update to tag version
- **WHEN** a user selects a tag version for an action
- **THEN** the action line is updated to use the tag
- **AND** no comment is appended to the line

#### Scenario: Update action with existing comment
- **WHEN** a user updates an action that already has a comment
- **THEN** the action version is updated
- **AND** the existing comment is preserved if it's part of the version update
