---
parent: context-epic-44.md
workflow: tdd
---

# Story 44-4: Multi-judge test on high-variance scenarios

## Business Context

This is the validation story that answers: "Does multi-judge actually improve reliability in our specific context?" Academic research supports ensemble judging in general, but our benchmark scenarios, rubrics, and judge prompts are specific. If multi-judge doesn't reduce variance for us, it's adding cost (3x judge tokens) without value. This story provides empirical evidence for or against continued investment in multi-judge infrastructure.

## Technical Guardrails

**Key files:**
- `internal/results/multi-judge-validation/` — New directory for validation results
- Existing baseline data in `internal/results/benchmarks/` — Source for identifying high-variance scenarios

**Patterns to follow:**
- Use existing `/solo --multi-judge 3` from 44-1
- 3 runs per scenario × 3 judges = 9 judge invocations per scenario
- Compare coefficient of variation (CV) between single-judge and multi-judge
- Report Krippendorff's Alpha per scenario from 44-2

**Integration points:**
- Depends on all three prior stories (44-1, -2, -3) — needs full system working
- Results inform priority decisions for PROJ-16210 (anchored rubrics)

**Do NOT:**
- Modify any code — this is a test/validation story, not implementation
- Cherry-pick scenarios to make multi-judge look good — use highest-variance scenarios objectively

## Scope Boundaries

**In scope:**
- Identify 5 highest-variance scenarios from existing baseline data (by std_dev)
- Run each with `--multi-judge 3` for 3 runs
- Calculate and report: Krippendorff Alpha per scenario, CV comparison, dimension-level agreement
- Store results in `internal/results/multi-judge-validation/`
- Written summary with variance reduction analysis and cost analysis (tokens/run)

**Out of scope:**
- Code changes to judge or solo commands
- Running on all scenarios (just 5 high-variance ones)
- Automated regression testing (this is a one-time validation)

## AC Context

**AC: 5 high-variance scenarios identified from existing baseline data**
- Sort all scenarios by std_dev of single-judge scores (descending)
- Select top 5
- Document selection rationale with actual std_dev values
- Test: Verify selected scenarios have highest variance in the dataset

**AC: Each scenario run with --multi-judge 3 (3 judges × 3 runs = 9 invocations per scenario)**
- Total: 5 scenarios × 9 = 45 judge invocations
- Each run produces 3 judge files + aggregated score
- Test: Verify all 45 judge files exist and are valid

**AC: Report includes Krippendorff Alpha per scenario, CV comparison, dimension-level agreement**
- Per-scenario table: single-judge CV vs multi-judge CV
- Per-dimension agreement: which dimensions do judges agree/disagree on?
- Overall Alpha across all scenarios
- Test: Report contains all required metrics with no missing values

**AC: Results stored in `internal/results/multi-judge-validation/`**
- Directory contains per-scenario subdirectories with raw judge files
- Summary report at `internal/results/multi-judge-validation/report.md`
- Test: Directory structure matches expected layout

**AC: Written summary answers key questions**
- Does multi-judge reduce effective variance? (CV comparison)
- By how much? (percentage reduction)
- Cost analysis: how many additional tokens per run?
- Recommendation: is 3 judges the right default, or should it be 2 or 5?
- Test: Summary addresses all four questions with data-backed answers
