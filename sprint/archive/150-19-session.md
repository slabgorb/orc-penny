---
story_id: "150-19"
epic: PROJ-16564
workflow: tdd
repos:
  - pennyfarthing
branch: feat/150-19-quality-regression-policy
---

# 150-19: Zero quality regression policy — test ratchet enforcement

## Objective
Detect test quality regressions: removed assertions, added skips without justification,
weakened assertions, removed test functions. The ratchet principle: test suite quality
only tightens, never loosens.

## Workflow: TDD

### Phase 1: TEA (RED)
- **Status:** complete
- **Agent:** TEA
- **Tests:** `pennyfarthing-dist/src/pf/tests/test_150_19_quality_ratchet.py`

### Phase 2: Dev (GREEN)
- **Status:** complete
- **Agent:** Dev
- **Module:** `pf.quality.ratchet`

### Phase 3: Reviewer
- **Status:** complete
- **Agent:** Reviewer
- **Decision:** APPROVED

## Reviewer Assessment

**Diff reviewed:** `git diff develop...HEAD` (3 files, 519 insertions)

### Findings

**Strengths:**
- Clean TDD discipline: RED commit (import fails) followed by GREEN commit (23/23 pass)
- Good test coverage across all four regression types with edge cases (refactored-not-weakened, skip-with-issue, empty inputs, added tests)
- `Regression` TypedDict provides type hints without runtime overhead
- Detection logic correctly distinguishes weakened assertions from refactored ones (e.g., `isinstance` to `type() is` is not flagged)
- Skip-with-linked-issue exception prevents false positives on legitimate skips

**Minor observations (not blocking):**
1. **Repeated `.splitlines()` calls in skip detection** (lines 155, 162, 165 of ratchet.py): `new_test_content.splitlines()` is called multiple times in the inner loop. Could cache once. Performance impact is negligible for expected input sizes.
2. **`_extract_test_functions` only handles top-level `def test_*`**: Does not parse test methods inside classes. Acceptable for the stated scope (Python test files using `assert`) but worth noting for future extension.
3. **Unused `Regression` TypedDict**: Defined but `detect_test_regressions` returns `list[dict]` not `list[Regression]`. Consider using it in the return type annotation for stronger typing.
4. **`pytest` import in test file is unused** (imported but no `@pytest.mark` or `pytest.raises` used in test code itself; it appears in fixture strings only). Harmless but linters may flag it.

**Verdict:** All findings are minor style/optimization points. The module is correct, well-tested, and follows project conventions. No security, correctness, or architectural concerns.

### Decision: APPROVED
