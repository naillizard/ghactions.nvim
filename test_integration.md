# Integration Test

This file demonstrates the GitHub Actions plugin functionality.

## Test Actions in this file:

- uses: actions/checkout@v3
- uses: actions/setup-node@v3  
- uses: codecov/codecov-action@v3

## Testing Commands:

1. `:GhActionsVersions actions/checkout` - Browse checkout versions
2. `:GhActionsSecure` on line with `uses: actions/checkout@v3` - Secure to specific commit
3. `:GhActionsUnsecure` on line with secured action - Restore tagged version
4. `:GhActionsCacheStats` - Show cache statistics
5. `:GhActionsVersions joybusinessacademy/devops_github_workflows/.github/workflows/workflow-dispatch.yml` - Resolve reusable workflow versions (requires authenticated gh)
