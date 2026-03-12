# ADR-0038: Story Demo Artifact Generator Architecture

**Status:** Proposed
**Date:** 2026-03-12
**Author:** Architect Agent
**PRD:** `sprint/planning/demo-prd.md`

## Context

Every completed story should produce a presentation-ready demo artifact automatically. The artifact explains what changed, why it matters, and why this engineering approach was chosen — written at ELI5 level for non-technical management audiences.

The Pennyfarthing framework already has machine-readable story data (sprint YAML, session files, PR metadata) and a story completion pipeline (`pf sprint story finish`) with a clear integration seam. The challenge is wiring these signals through classification, AI-powered content generation, and mechanical artifact assembly into a reliable, zero-effort pipeline.

### Architecture Constraints

- Python only (ADR-0034)
- Result objects `{success, data?, error?}` for all functions (ADR-0008)
- Fail hard — no partial output, no placeholders
- `pennyfarthing-dist/` is source of truth; `.pennyfarthing/` for runtime paths
- Generation in minutes is acceptable; Playwright gets hard timeouts

## Decision Drivers

1. **Signal collection timing** — Session and dialogue files are archived/deleted during `story_finish`. Collector must run before archival.
2. **PR diff access** — PR may be merged during finish. Must capture diff before merge or from merge commit.
3. **Classification-based format selection** — PRD requires different artifact formats per story type, not degradation/fallback.
4. **AI content quality** — Generator must translate technical signals to management-readable content without hallucinating claims.
5. **Optional dependencies** — Playwright (screenshots) and python-pptx (slides) must not be hard requirements for all consumers.

## Considered Options

| Pattern | Fit | Rationale |
|---------|-----|-----------|
| **Pipeline** | Selected | Sequential stages with fail-hard short-circuit. Maps directly to collect → classify → generate → assemble flow. |
| **Strategy** | Selected | Story type classification drives format selection. Each type maps to a strategy defining which artifacts to produce. |
| **Helper Delegation** | Selected | Opus-class reasoning for ELI5 translation, Haiku-class for mechanical assembly. Existing PF pattern. |
| Event-Driven | Rejected | Single trigger point (story finish). Event bus adds indirection for no benefit. Direct function call is simpler. |

## Decision Outcome

A five-stage pipeline with strategy-based format selection and helper delegation for AI content generation.

### Pipeline Flow

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
    │ Generator │──── AI content creation
    └────┬──────┘
         │ GeneratedContent
    ┌────▼──────┐
    │ Assembler │──── builds final artifacts
    └────┬──────┘
         │
         ▼
  sprint/demos/<story-id>/
```

### Components

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| **DemoOrchestrator** | Pipeline entry point. Runs stages sequentially, short-circuits on failure. | All stages |
| **Collector** | Gathers story signals: ACs from sprint YAML, PR diff via `gh`, commit messages via `git log`, session file fields, review findings. | `pf.sprint.loader`, `gh` CLI, git |
| **Classifier** | Determines story type (ui, backend, infrastructure, refactor, bugfix) from signals. Rule-based, deterministic. No AI. | Collector output, config |
| **Generator** | Translates signals into ELI5 content via Claude: problem statement, what changed, why this approach, before/after, demo script. | Claude (subagent) |
| **Assembler** | Builds final artifacts per strategy: PPTX slides, mermaid diagrams, demo scripts. Pure mechanical Python. | `python-pptx`, filesystem |
| **Config** | Reads `demo.yaml` for branding, format prefs, classification rule overrides. Optional — sensible defaults work without it. | Filesystem |

### Interfaces

**Entry points:**
- `pf demo generate <story-id>` — CLI (Click command, lazy-loaded via `_LAZY_COMMANDS`)
- `pf demo generate <story-id> --dry-run` — preview without writing
- `pf demo generate <story-id> --corrections "fix slide 2 claim"` — regenerate with developer feedback
- `/pf-demo <story-id>` — Claude Code skill
- Direct call from `story_finish.py` as step 0 (before session archival)

**Internal contracts (dataclasses):**

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
    story_type: StoryType   # enum: ui, backend, infrastructure, refactor, bugfix
    artifacts: list[ArtifactType]

@dataclass
class GeneratedContent:
    problem_statement: str
    what_changed: str
    why_this_approach: str
    before_after: str | None
    demo_script: str
    diagram_source: str | None
    slide_outline: list[dict]   # supports multi-pass for long decks
```

**Generator accepts optional corrections:**
```python
def generate_content(
    classified: ClassifiedStory,
    corrections: str | None = None,  # developer feedback for regeneration (FR22)
) -> OperationResult[GeneratedContent]:
    ...
```

When `corrections` is provided, the Generator prompt includes the previous output and the correction instructions, producing a revised version. The Assembler then overwrites `sprint/demos/<story-id>/` as normal (FR20).

**Multi-pass generation:** For complex stories requiring long decks (30+ slides), the Generator splits content across multiple Claude calls, each producing a batch of slides. The Assembler concatenates them. Artifact length is driven by story complexity, not tool limitations (PRD NFR).

**Output structure:**
```
sprint/demos/<story-id>/
  ├── deck.pptx              # PPTX for MVP; PDF export is Phase 2
  ├── demo-script.md
  ├── narrative.md
  ├── diagram.mmd            # mermaid source (backend/infra/refactor)
  ├── diagram.png            # rendered via mmdc if available, otherwise omitted
  ├── screenshots/            # ui only, via Playwright
  └── metadata.yaml
```

**Story type → artifact mapping:**

| Story Type | Artifacts |
|------------|-----------|
| UI | Screenshots + slide deck + demo script |
| Backend | Architecture diagrams + narrative + demo script |
| Infrastructure | Architecture diagrams + narrative + demo script |
| Refactor | Before/after comparison + rationale narrative |
| Bug fix | Problem statement + resolution narrative |

### Diagram Rendering

The Assembler generates mermaid source (`.mmd`) for backend/infrastructure/refactor stories. Image rendering follows the same optional-dependency pattern as Playwright:

1. Assembler checks if `mmdc` (mermaid CLI) is available on PATH
2. If available: renders `.mmd` → `.png`, embeds PNG in PPTX slides
3. If unavailable: `.mmd` file is written alongside the deck; slides reference "see diagram.mmd". No failure — diagrams render natively in GitHub and VS Code.

### PDF Export (Phase 2)

MVP produces PPTX only. PDF export will be added in Phase 2 via one of:
- LibreOffice CLI headless conversion (`libreoffice --headless --convert-to pdf`)
- `weasyprint` for narrative-to-PDF (markdown → HTML → PDF)

The Assembler's output file list is extensible — adding PDF is a new output step, not a redesign.

### Module Location

All code in `pennyfarthing-dist/src/pf/demo/`:
```
demo/
  __init__.py
  cli.py            # Click group: pf demo generate
  orchestrator.py   # DemoOrchestrator.generate()
  collector.py      # collect_signals() → SignalBundle
  classifier.py     # classify_story() → ClassifiedStory
  generator.py      # generate_content() → GeneratedContent
  assembler.py      # assemble_artifacts() → writes files
  config.py         # load_config() → DemoConfig
  models.py         # dataclasses, enums
```

CLI registration — one line in `cli.py`:
```python
"demo": ("pf.demo.cli", "demo"),
```

## Consequences

### Positive

- Zero developer effort for demo artifacts — fires automatically on story completion
- Classification-based format selection produces appropriate artifacts per story type
- Pipeline pattern makes failures obvious and debuggable — each stage has clear inputs/outputs
- Reuses existing PF infrastructure (sprint loader, session parser, CLI framework, skill system)
- Human review loop (developer checks before presenter) catches AI quality issues

### Negative

- New dependency: `python-pptx` for slide generation
- AI content generation adds cost per story completion (Claude API call)
- Signal collection ordering in `story_finish.py` creates a coupling — generator must run before archival

### Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Signal collection timing | High | Run as step 0 before session archival |
| AI hallucination | High | Prompt constrained to signals; human review loop |
| PR diff unavailable | Med | Fallback: `git diff <merge-base>..HEAD` |
| Playwright not installed | Med | Optional; classifier checks availability |
| Large diffs | Med | Truncate to configurable max (50K chars) |

## Implementation Consistency Rules

> These rules prevent AI agents from making conflicting implementation choices.

1. All demo code lives in `pennyfarthing-dist/src/pf/demo/`. No demo logic elsewhere.
2. `DemoOrchestrator.generate(story_id) → OperationResult` is the only public API. CLI and skill both call this.
3. Signal collection runs before session archival and PR merge in `story_finish.py`.
4. Classification is deterministic — rule-based only, no AI.
5. Only Generator invokes Claude. Assembler is pure mechanical Python.
6. Output always to `sprint/demos/<story-id>/`. Never `.session/`, never temp dirs.
7. All functions return `{success, data?, error?}`. No exceptions for business logic.
8. Config is optional — sensible defaults work without `demo.yaml`.

## Related Decisions

- **ADR-0034:** Post-Migration Architecture — Python runtime constraint
- **ADR-0008:** Result Object Error Handling — `{success, data?, error?}` pattern
- **ADR-0009:** Session File Coordination — session file patterns
