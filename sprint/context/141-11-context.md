# Story 141-11: Type OTLP Receiver Payloads Properly

**Story ID:** 141-11
**Jira:** MSSCI-16138
**Workflow:** tdd
**Repos:** pennyfarthing

## Context

Replace `any` types on OTLP (OpenTelemetry Protocol) receiver payloads with proper TypeScript interfaces. Part of the Tech Debt Audit epic (141) focusing on type safety improvements.

## Acceptance Criteria

- OTLP receiver payloads have proper TypeScript types
- No `any` types remain on OTLP-related interfaces
- Existing tests pass with new types
- New type definitions are exported for consumers

## Technical Approach

1. Identify all OTLP receiver payload types currently using `any`
2. Define proper TypeScript interfaces for each payload structure
3. Apply types to receiver implementation
4. Update tests to validate new types
5. Export types from appropriate package exports

## Implementation Notes

- 2-point TDD story
- Workflow: Test Engineer (Sam Seaborn) designs tests first, then Developer (Toby) implements types
- Straightforward type safety improvement
