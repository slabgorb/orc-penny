---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7]
prd: sprint/planning/demo-prd.md
date: 2026-03-12
author: architect
status: complete
---

# Architecture Decision: Story Demo Artifact Generator

## Architecture Session

### Inputs Gathered
- **PRD:** `sprint/planning/demo-prd.md` — auto-generated demo artifacts on story completion
- **Relevant ADRs:**
  - ADR-0034: Post-Migration Architecture — Python runtime, React GUI-only
  - ADR-0008: Result Object Error Handling — `{success, data?, error?}` pattern
  - ADR-0009: Session File Coordination — session file patterns, phase ownership
  - ADR-0025: Script-First Gate Extraction — gate schema, handoff CLI
- **Existing infrastructure:**
  - `pf sprint story finish` hook pipeline — auto-trigger integration point
  - Skill system — `pf-{name}/skill.md` pattern for `/pf-demo`
  - Python CLI at `pennyfarthing-dist/src/pf/` — home for `pf demo` subcommand
  - Sprint data already machine-readable (YAML stories, session files, PR data)

### Constraints
- Python only (ADR-0034)
- Result objects for all functions (ADR-0008)
- `pennyfarthing-dist/` is source of truth; `.pennyfarthing/` for runtime
- Fail hard, no partial output (PRD NFR)
- No timeline restrictions

### Stakeholders
- Decision maker: Keith Avery (framework owner)

## Architecture Context

### Technical Constraints
- Python only (ADR-0034)
- Result objects `{success, data?, error?}` for all functions (ADR-0008)
- Fail hard — no partial output, no placeholders
- `.pennyfarthing/` paths at runtime, `pennyfarthing-dist/` is source of truth
- Generation in minutes acceptable; Playwright gets hard timeouts

### Current Landscape
- Sprint loader: `pf.sprint.loader.get_story_by_id()` — ACs, title, points, Jira key
- Session files: `.session/{id}-session.md` — PR number, branch, Jira key
- Story finish pipeline: `pf.sprint.story_finish.finish_story()` — 7 steps, natural seam between 4b and 5
- CLI registration: `LazyGroup` + `_LAZY_COMMANDS` — one-line add for `pf demo`
- Skill system: `.claude/skills/pf-{name}/skill.md` — pattern for `/pf-demo`

### Key Concerns
1. Signal collection timing — session/dialogue files archived during story finish; collect before archival
2. PR diff access — PR may be merged by step 2; generator runs before merge or diffs against merge commit
3. Playwright dependency — optional, only for UI stories
4. PPTX generation — `python-pptx` 0.6.22, pure Python
5. Mermaid — text `.mmd` files for MVP, render natively in GitHub/VS Code
6. AI generation — Claude translates signals to ELI5 narratives (AI-calling-AI pattern)

## Pattern Selection

### Selected Patterns
1. **Pipeline** — Sequential stages: collect → classify → generate → assemble → write. Fail-hard short-circuits on any stage failure.
2. **Strategy** — Story type classification drives format selection. Each type maps to a strategy that knows which artifacts to produce.
3. **Helper Delegation** — Opus-class reasoning for ELI5 translation, Haiku-class for mechanical assembly. Existing PF pattern.

### Rejected
- Event-driven: one trigger, no bus needed — direct function call
- Microservices: CLI tool, not distributed

## Component Design

### Component Diagram

```
pf demo generate <story-id>
         │
         ▼
┌──────────────────┐
│  DemoOrchestrator │──── pipeline entry point
└────────┬─────────┘
         │
    ┌────▼────┐
    │Collector │──── gathers all signals
    └────┬────┘
         │ SignalBundle
    ┌────▼──────┐
    │Classifier │──── story type → strategy
    └────┬──────┘
         │ ClassifiedStory
    ┌────▼──────┐
    │ Generator │──── AI content creation (Opus)
    └────┬──────┘
         │ GeneratedContent
    ┌────▼──────┐
    │ Assembler │──── builds final artifacts (Haiku)
    └────┬──────┘
         │
         ▼
  sprint/demos/<story-id>/
```

### Component Responsibilities

| Component | Responsibility | Data Owned | Dependencies |
|-----------|---------------|------------|--------------|
| DemoOrchestrator | Pipeline entry point. Sequential stages, short-circuits on failure. | Pipeline state | All stages |
| Collector | Gathers story signals: ACs, PR diff, commits, session fields, review findings. | SignalBundle | pf.sprint.loader, gh CLI, git, session parser |
| Classifier | Determines story type (ui, backend, refactor, bugfix) from signals. Rule-based, deterministic. | Classification rules (config) | Collector output |
| Generator | Translates signals into ELI5 content via Claude. Problem, what, why, before/after. | Generated text | Claude subagent |
| Assembler | Builds final artifacts per strategy: PPTX, mermaid, demo scripts. Writes output. | Output files | python-pptx, filesystem |
| Config | Reads demo.yaml for branding, format prefs, classification overrides. Optional. | Config schema | Filesystem |

### Boundary Contracts
- Collector → Classifier: `SignalBundle` dataclass (story metadata, ACs, diff, commits, session fields, review notes)
- Classifier → Generator: `ClassifiedStory` (SignalBundle + story_type enum + artifact_list)
- Generator → Assembler: `GeneratedContent` (dict of artifact_type → content string)
- All stages → Orchestrator: `{success, data?, error?}` result objects

### Implementation Consistency Rules
1. All demo code in `pennyfarthing-dist/src/pf/demo/`
2. `DemoOrchestrator.generate(story_id) → OperationResult` is the only public API
3. Signal collection runs before session archival and PR merge in story_finish
4. Classification is deterministic — rule-based, no AI
5. Only Generator invokes Claude. Assembler is pure mechanical Python.
6. Output always to `sprint/demos/<story-id>/`
7. Config optional — sensible defaults without demo.yaml

## Interface Definitions

### External APIs

| Interface | Signature | Purpose |
|-----------|-----------|---------|
| `pf demo generate <story-id>` | Click command → `DemoOrchestrator.generate(story_id)` | Manual trigger |
| `pf demo generate <story-id> --dry-run` | Same, prints plan without writing | Preview |
| `/pf-demo <story-id>` | Skill wrapper → same CLI | Claude Code skill |
| `story_finish.py` step 0 | Direct call to `generate(story_id)` | Auto-trigger |

### Internal Contracts (Dataclasses)

```python
@dataclass
class SignalBundle:
    story_id: str
    title: str
    jira_key: str | None
    points: int | None
    acceptance_criteria: list[str]
    pr_diff: str
    commit_messages: list[str]
    session_fields: dict[str, str]
    review_findings: str | None
    file_extensions: set[str]

@dataclass
class ClassifiedStory:
    signals: SignalBundle
    story_type: StoryType   # enum: ui, backend, refactor, bugfix
    artifacts: list[ArtifactType]

@dataclass
class GeneratedContent:
    problem_statement: str
    what_changed: str
    why_this_approach: str
    before_after: str | None
    demo_script: str
    diagram_source: str | None
    slide_outline: list[dict]
```

### Output Convention

```
sprint/demos/<story-id>/
  ├── deck.pptx
  ├── demo-script.md
  ├── narrative.md
  ├── diagram.mmd          # backend/refactor only
  ├── screenshots/          # ui only
  └── metadata.yaml
```

### Conventions
- snake_case everywhere (Python modules, config keys, function names)
- All functions return `{success, data?, error?}` — no exceptions for business logic
- kebab-case for output filenames

## Risk Assessment

### Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Signal collection timing — session archived before collector | High | High if wired wrong | Run as step 0 in story_finish, before archival |
| PR diff unavailable — merged or no PR | Med | Med | Try `gh pr diff`, fall back to `git diff <merge-base>..HEAD` |
| AI content hallucination | High | Med | Prompt constrained to signal data; human review loop |
| python-pptx output quality | Low | High | Simple templates, good enough beats pretty |
| Playwright not installed for UI story | Med | Low | Classifier checks availability, falls back to narrative-only with warning |
| Large diffs overflow context | Med | Low | Truncate to 50K chars configurable max |

### Failure Modes

| Component | Failure | Recovery |
|-----------|---------|----------|
| Collector | gh CLI not authenticated | Error: "Run `gh auth login`" |
| Collector | Story not found | Error: "Story {id} not found in current sprint" |
| Classifier | No rules match | Default to backend type |
| Generator | Claude API failure | Error with retry instruction |
| Assembler | python-pptx not installed | Error: "Install python-pptx" |

### Security
- PR diffs may contain secrets — Generator summarizes changes, never includes raw diff in output
- No credentials in metadata.yaml or demo.yaml config

### AI Implementation Risks

| Risk | Prevention |
|------|------------|
| Agent puts AI in Classifier | Consistency rule #4: rule-based only |
| Agent generates content in Assembler | Consistency rule #5: only Generator calls Claude |
| Agent skips result objects | Consistency rule #7 + type hints |
| Agent puts files in .session/ | Consistency rule #6: always sprint/demos/ |
| Agent makes Playwright a hard dep | Classifier checks availability; optional import |
