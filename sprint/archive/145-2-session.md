# Story 145-2: Story type classifier — rule-based type detection and format mapping

## Story Details
- **ID:** 145-2
- **Jira Key:** (to be created)
- **Workflow:** tdd
- **Stack Parent:** none
- **Repos:** pennyfarthing
- **Branch:** feat/145-2-story-type-classifier

## Acceptance Criteria
- [ ] Deterministic rule-based story type detection (UI, backend, infrastructure, refactor, bugfix)
- [ ] Classification consumes SignalBundle from Collector (145-1)
- [ ] Output ClassifiedStory dataclass with story_type and artifacts list
- [ ] Rules implementation: file extension detection, title keyword matching, config override support
- [ ] Config override pattern tested: optional demo.yaml rules evaluated before built-in rules
- [ ] Ambiguous classifications fail hard (return error, no fallback)
- [ ] All functions return {success, data?, error?} per ADR-0008
- [ ] No AI/ML — rules are purely deterministic

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T01:15:34Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-12 | 2026-03-13T00:33:20Z | 24h 33m |
| red | 2026-03-13T00:33:20Z | 2026-03-13T00:36:36Z | 3m 16s |
| green | 2026-03-13T00:36:36Z | 2026-03-13T01:12:45Z | 36m 9s |
| verify | 2026-03-13T01:12:45Z | 2026-03-13T01:14:16Z | 1m 31s |
| review | 2026-03-13T01:14:16Z | 2026-03-13T01:15:34Z | 1m 18s |
| finish | 2026-03-13T01:15:34Z | - | - |

## Story Context

### Dependencies
- **Depends On:** 145-1 (Signal Collector) — must complete first
- **Blocked By:** None
- **Unblocks:** 145-3 (Content Generator), 145-7 (Orchestrator)

### Technical Approach
Deterministic story type detection via:
1. Config rules (from optional demo.yaml) — evaluated first
2. Built-in rules — file extension matching, title keyword matching
3. Fail hard on ambiguous classifications

**Input:** SignalBundle from 145-1
- signals.story_id
- signals.title
- signals.file_extensions (set of .rs, .py, .ts, etc.)
- signals.pr_diff (for extension detection)
- signals.acceptance_criteria

**Output:** ClassifiedStory dataclass
```python
@dataclass
class ClassifiedStory:
    signals: SignalBundle
    story_type: StoryType  # enum: ui, backend, infrastructure, refactor, bugfix
    artifacts: list[ArtifactType]  # [ui_screenshots, slide_deck, demo_script, mermaid_diagram, narrative]
```

### Classification Rules (From PRD)

| Story Type | Detection Rule | Artifacts |
|------------|---|---|
| **UI** | title contains "UI\|screen\|button\|form\|layout" OR signals.file_extensions has `.tsx`, `.jsx`, `.css` | screenshots + slide_deck + demo_script |
| **Backend** | file_extensions has `.rs`, `.py`, `.go`, `.java` AND NOT ui-keywords; title contains "API\|endpoint\|database\|query" | mermaid_diagram + narrative + demo_script |
| **Infrastructure** | title contains "infra\|deployment\|docker\|ci/cd\|k8s"; OR files: Dockerfile, .github, terraform | mermaid_diagram + narrative + demo_script |
| **Refactor** | title contains "refactor\|cleanup\|tech-debt\|simplify" | before_after_comparison + narrative |
| **Bug Fix** | title contains "fix\|bug\|patch\|regression" | problem_statement + narrative |

### Implementation Pattern
- All functions return {success, data?, error?} (ADR-0008 pattern)
- Config loading: optional demo.yaml → `load_config()` from common.config
- Use regex for title keyword matching (case-insensitive)
- Fail hard if classification is ambiguous
- Reuse SignalBundle/ClassifiedStory dataclasses from models.py (145-1)

### Testing Strategy
- Unit tests: determinism (same input → same output)
- Config override behavior (demo.yaml rules before built-in)
- Edge cases: ambiguous titles, missing extensions, empty signals
- Mock SignalBundle inputs for each story type
- Verify ClassifiedStory structure completeness

## SM Assessment

Story 145-2 is a clean 2-point classifier. Pure deterministic rules — no ML, no ambiguity tolerance. SignalBundle from 145-1 feeds in, ClassifiedStory comes out. The Caterpillar should write RED tests covering all 5 story types plus ambiguity rejection and config override.

**Routing:** tdd phased → TEA (red) → Dev (green) → TEA (verify) → Reviewer → SM (finish)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story is a classifier with 5 story types, config overrides, and ambiguity rejection — must be tested.

**Test Files:**
- `tests/python/test_demo_classifier.py` — 54 tests across 12 test classes

**Tests Written:** 54 tests covering all 8 ACs
- AC1: 5 story type classifications (UI=9, Backend=6, Infra=6, Refactor=5, Bugfix=5 tests)
- AC2: SignalBundle consumption (3 tests)
- AC3: ClassifiedStory output structure (3 tests)
- AC4: File extension + title keyword rules priority (4 tests)
- AC5: Config override via demo.yaml (5 tests)
- AC6: Ambiguous classification hard failure (2 tests)
- AC7: ADR-0008 result objects (4 tests)
- AC8: Determinism (2 tests)

**Status:** RED (54 failing — all on NotImplementedError, ready for Dev)

**Stubs Created:**
- `models.py` — added StoryType enum, ArtifactType enum, ClassifiedStory dataclass
- `classifier.py` — classify_story() and load_classification_config() stubs

**Handoff:** To Dev (White Rabbit) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/demo/classifier.py` — full classifier implementation (185 lines)

**Tests:** 54/54 passing (GREEN)
**Branch:** feat/145-2-story-type-classifier (pushed)

**Handoff:** To TEA (Caterpillar) for verify phase

## TEA Verify Assessment

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | clean | No duplication or extraction opportunities |
| simplify-quality | clean | Naming, types, architecture all consistent |
| simplify-efficiency | clean | No over-engineering or unnecessary complexity |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 medium-confidence findings
**Noted:** 0 low-confidence observations
**Reverted:** 0

**Overall:** simplify: clean

**Quality Checks:** All 54 tests passing
**Handoff:** To Reviewer (Queen of Hearts) for code review

## Delivery Findings

No upstream findings at setup.

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- No upstream findings during code review.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** SignalBundle → classify_story → keyword/extension matching → ClassifiedStory (safe — no external calls, pure deterministic logic)
**Pattern observed:** ADR-0008 result objects consistently applied across classify_story and load_classification_config at classifier.py:68,138
**Error handling:** Config file missing → graceful fallback at classifier.py:83. Invalid YAML → caught at classifier.py:158. Invalid enum values → caught at classifier.py:210.
**Security:** yaml.safe_load used (classifier.py:154). Config regex is developer-controlled, not user input. No injection vectors.
**Word boundaries:** re.escape(kw) prevents regex injection from constants (classifier.py:170). Special keywords (ci/cd, tech-debt) work correctly with \b.

**Observations:**
1. [VERIFIED] All public functions return ADR-0008 result objects — no thrown exceptions
2. [VERIFIED] Determinism — pure functions, no state, no randomness
3. [VERIFIED] ARTIFACT_MAP copy at line 183 prevents constant mutation
4. [VERIFIED] yaml.safe_load — no arbitrary code execution risk
5. [VERIFIED] Bugfix deprioritization is well-reasoned — "fix" is too generic to cause ambiguity

**Handoff:** To SM (Mad Hatter) for finish-story

## Design Deviations

### TEA (test design)
- **Backend classification guard:** Spec says "file_extensions has backend exts AND NOT ui-keywords". Tests enforce that UI keywords take precedence when both backend extensions and UI keywords are present. This is the logical interpretation of "AND NOT".
- **Ambiguous test case:** Spec example "Refactor API UI" used directly. Tests assert `success: False` with "ambiguous" in error message. The exact ambiguity detection strategy is left to Dev.
- **Config artifact values:** Config demo.yaml uses string artifact names (e.g., "narrative") which Dev must map to ArtifactType enum values.

### Dev (implementation)
- **Bugfix deprioritization:** Spec says "fail hard on ambiguous" but bugfix keywords (fix, bug, patch) are too generic — they appear in many non-bugfix titles (e.g., "Fix ci/cd pipeline timeout" is infra, not bugfix). Implementation deprioritizes bugfix when a more specific category also matches. Only truly ambiguous cross-category combinations (e.g., refactor + UI) return error. → ✓ ACCEPTED by Reviewer: Sound design — "fix" as a verb is ubiquitous and would cause false ambiguity in most real titles.
- **Config loader separate function:** Spec mentioned `load_config()` from common.config, implemented as `load_classification_config()` in classifier.py with its own ADR-0008 result object. Reason: classifier config is demo-specific, not a general config concern. → ✓ ACCEPTED by Reviewer: Keeps demo module self-contained.

### Reviewer (audit)
- No undocumented deviations found. All TEA and Dev deviations reviewed and accepted.