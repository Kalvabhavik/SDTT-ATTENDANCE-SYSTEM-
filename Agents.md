# Attendrix Engineering Standards

## Objective
Build a reliable, secure, accessible, maintainable attendance application. Prioritize correctness and user trust over visual novelty or code volume.

## Before coding
- Inspect existing implementations and related tests.
- Identify the actual root cause before changing code.
- Read current official documentation for unfamiliar or version-sensitive APIs.
- Understand the existing architecture before introducing dependencies.
- Write a short implementation plan for nontrivial changes.

## Implementation standards
- Implement complete features, not decorative placeholders.
- Never fabricate API responses, attendance results, verification scores, or dashboard metrics.
- Do not create mock functionality in production code.
- Reuse existing components and patterns where appropriate.
- Keep modules cohesive and changes as small as reasonably possible.
- Avoid unnecessary dependencies, duplicated logic, giant components, and speculative abstractions.
- Use typed interfaces, explicit error handling, and appropriate validation.
- Never silently ignore failures.

## Design standards
- Establish a consistent design system for typography, spacing, colors, and components.
- Prioritize clarity, hierarchy, accessibility, and responsive layouts.
- Avoid unnecessary gradients, glass effects, excessive animation, generic dashboard cards, and decorative charts.
- Every button and form must perform a real, defined action.
- Every screen must handle loading, empty, error, and success states.
- Use realistic content and actual backend data.
- Validate the result in a browser or emulator instead of judging code alone.

## Attendance integrity
- Only the backend can authorize and persist final attendance.
- Never trust client-supplied identity, roles, verification scores, or attendance status.
- Enforce session expiry, authorization, idempotency, and database constraints.
- Preserve uncertain outcomes for appropriate review.
- Never claim liveness detection, biometric accuracy, or classroom presence without evidence.
- Do not log raw images, biometric templates, credentials, or authentication tokens.

## Testing requirements
- Add tests for every meaningful behavior and bug fix.
- Include negative tests for authorization and invalid input.
- Test database consistency and duplicate requests.
- Run relevant formatters, linters, type checks, and tests.
- Build affected applications after changes.
- Report exact commands and results.
- Never disable a test merely to make the suite pass.

## Security and deployment
- Never commit secrets or expose privileged keys to clients.
- Use migrations and review destructive database operations.
- Follow least-privilege authorization.
- Validate uploaded files and limit resource consumption.
- Do not deploy without authorization and successful checks.
- Document any unresolved security or production blocker.

## Definition of done
A task is complete only when its implementation, tests, relevant UI states, documentation, and verification evidence are present. Clearly identify any untested behavior or external blocker.
