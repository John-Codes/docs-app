---
name: Pull Request
about: Template for all pull requests
title: ''
labels: ''
assignees: ''
---

## Description

Brief description of changes.

## Testing

- [ ] All new/changed tests fail when the targeted behavior is deliberately broken and pass when correct (Rule 3 verification)
- [ ] Tests exercise real application components (no mocking the system under test)
- [ ] E2E tests cover affected critical user workflows
- [ ] All CI checks pass locally before pushing

## Checklist

- [ ] Code follows the project's branch rules (BRANCH_UPDATE_RULES.md)
- [ ] No direct pushes to `main` — changes are via PR
- [ ] New tests are in independent files, auto-discovered by the test runner
- [ ] No existing behavior broken; new fields/values default for backward compatibility

## Verification (Rule 3)

**Describe how you verified the new/changed tests detect failures:**

> Example: "Changed the expected status code from 200 to 400 in the test, ran it, confirmed it failed. Restored to 200, ran it, confirmed it passed."

---

*This project enforces the Testing & Merge Policy (see BRANCH_UPDATE_RULES.md). All required checks must pass before merge.*