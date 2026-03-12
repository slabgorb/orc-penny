# Story 47-2: Write Concern Manifest and AC Manifest for dpgd-116

## Overview

Create ground truth reference documents for dpgd-116: a concern manifest (what a good PM/Architect should flag) and an AC manifest (what acceptance criteria should cover). These serve as scoring rubrics for evaluating PM/Architect persona output in stories 47-3 through 47-5.

**Points:** 2 | **Workflow:** trivial | **Jira:** MSSCI-16295

## Objective

The dpgd-116 scenario has 7 seeded defects. A well-informed PM should anticipate the concern areas (input validation, error handling, security surface, etc.) without seeing the actual defects. An Architect should flag structural risks. These manifests define "what good looks like" for strategic roles.

## Approach

### Concern Manifest

List the concerns a PM should raise when given the dpgd-116 scenario description and codebase overview (without seeing seeded defects):

```yaml
concerns:
  - area: error-handling
    description: How does the service handle malformed input and upstream failures?
    related_findings: [C1, I3]
    priority: high
  - area: security-surface
    description: What CWEs are relevant for this service's attack surface?
    related_findings: [I1, I2]
    priority: high
  # ...
```

### AC Manifest

List the acceptance criteria a PM should write for a story implementing changes in this codebase:

```yaml
acceptance_criteria:
  - id: AC-1
    text: All public API endpoints validate input types and return structured errors
    related_findings: [C1, I3]
  - id: AC-2
    text: Error messages do not leak internal implementation details (CWE-209)
    related_findings: [I1]
  # ...
```

## Key Files

| File | Purpose |
|------|---------|
| `internal/results/pipeline-replay/dpgd-116/control/run-1/score.yaml` | Ground truth findings (7 defects with weights, severity, phase_ideal) |
| dpgd-116 scenario definition | Scenario codebase and description |

## Acceptance Criteria

- [ ] Concern manifest with 8-12 concerns mapped to findings
- [ ] AC manifest with 6-10 acceptance criteria mapped to findings
- [ ] Both written as YAML to `internal/results/manifests/dpgd-116-concern-manifest.yaml` and `dpgd-116-ac-manifest.yaml`
- [ ] Coverage: every finding maps to at least one concern and one AC
- [ ] Manifests are scenario-aware but defect-blind (a PM wouldn't know the seeded issues)

## Dependencies

- dpgd-116 scenario definition and ground truth (complete)
