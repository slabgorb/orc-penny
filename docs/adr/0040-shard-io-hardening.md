# ADR-0040: Shard I/O Hardening — Containment at the Chokepoint, Read-Hygiene per File

**Status:** Proposed
**Date:** 2026-06-23
**Author:** architect
**Stories:** 160-13 (path containment, p1, 1pt), 160-12 (read hygiene, p1, 2pt)
**Origin:** 160-4 Reviewer findings (rounds 1–2) — `sprint/archive/160-4-session.md` lines 79–80

## Context

Story 160-4 hardened a single shard-loading chokepoint (`ws_push.fetch_sprint`'s nested `_load_file`) against silent drops of malformed sprint shards. During that work the Reviewer logged two **pre-existing, out-of-diff** weaknesses that span the wider shard-I/O surface and became the two p1 follow-ups this ADR covers:

1. **CWE-22 path traversal (160-13)** — epic refs read from sprint YAML build filesystem paths via `base / f"epic-{ref}.yaml"` with no `resolve()`/containment check. A hostile or garbled ref (`../../…`) escapes the intended directory. Present in `shard_merge.py` and `ws_push.py`.
2. **CWE-838 read hygiene (160-12)** — six `read_text()` sites in `ws_push.py` lack `encoding=` and sit inside broad `except Exception` silent guards — the same fail-loud violation (gh #50) 160-4 fixed at one site, unfixed at the other six.

Ground-truth at design time established the fact that shapes the whole decision:

- `merge_epic_shards()` (in `shard_merge.py`) has **6 callers** — `ws_push.py`, `loader.py`, `yaml_io.py`, `validator.py` (×2), and the `sprint_yaml` validation hook — and **each injects its own `load_file` callable**. The module deliberately owns no reads; readers are dependency-injected so each caller keeps its YAML library (ruamel vs `safe_load`).
- The two vulnerable `read_text()`/path-construction families do **not** map 1:1. Containment lives where refs become paths (inside `merge_epic_shards`, plus two ws_push sites that bypass it). Read-hygiene lives at the seven `ws_push.py` read sites, one of which (`:189`) is already 160-4-hardened. The benchmark-history and persona reads have **no untrusted-ref → path step at all** (their paths come from `iterdir()`, inherently contained), so containment does not apply to them — only read-hygiene does.

The concerns intersect on the shard-loading sites but operate at **different moments** (build-path vs read-path) and each has sites the other never touches. That asymmetry is the architectural crux.

## Decision Drivers

1. **One Truth, One Place (SOUL #2)** — fix each concern once, where every consumer inherits it.
2. **Reuse debugged code** — 160-4 already wrote and hardened a read helper (`_load_file`); do not author a twin.
3. **Respect existing boundaries** — `shard_merge.py` owns path logic, not reads. Readers are injected by design; keep that contract intact.
4. **Containment must not re-introduce a silent drop** — a rejected ref must surface (warn + skip), never vanish (#50).
5. **Single-responsibility helpers** — path-containment and read-surfacing are orthogonal; do not fuse them.

## Considered Options

### Option 1: Two single-responsibility helpers at their correct altitudes (selected)

- `resolve_shard_path(base, ref) -> Path | None` in `shard_merge.py` for containment (the chokepoint + two bypass sites).
- Promote `ws_push._load_file` to a module-level read helper for the YAML read sites; bare `encoding=` + catch-narrowing for the plain-text reads.
- **Pro:** Containment fix at the chokepoint protects all 6 `merge_epic_shards` callers. Read helper reuses 160-4's debugged code. Each helper does one thing.
- **Pro:** `.resolve()`-based containment also closes the CWE-59 symlink-escape the 160-4 Reviewer noted, for free.
- **Con:** Two helpers in two modules; contributors must know which concern lives where (mitigated by this ADR + the chokepoint comment).

### Option 2: One fused `load_shard(base, ref) -> dict | None` (rejected)

A single helper that resolves + contains + reads + parses + warns.

- **Con:** Breaks `shard_merge`'s dependency-injection contract — it must not own reading (ruamel vs `safe_load` is the caller's choice).
- **Con:** Does not fit the benchmark/persona/narrative reads, which have no ref → path step, so a `(base, ref)` signature is meaningless there.
- **Con:** Forces read-hygiene into `shard_merge.py` (wrong module) or drags containment into directory-walk reads (no untrusted input to contain).

### Option 3: Per-site inline fixes, no shared helper (rejected)

Add a `.resolve()`/containment check and `encoding=` at each of the ~10 sites independently.

- **Con:** The exact "two near-identical helpers debugged separately" failure mode — containment logic copy-pasted to 4 sites, read logic to 6. Drift guaranteed.
- **Con:** Misses the chokepoint reuse: the other 5 `merge_epic_shards` callers stay unprotected against CWE-22.

## Decision Outcome

Two orthogonal, single-responsibility helpers, fixed at different altitudes.

### 160-13 — Path containment at the chokepoint

Add to `shard_merge.py` (already the canonical, read-agnostic shard module; already uses `.resolve()` for dedup at `:77, :106, :165, :182`):

```python
def resolve_shard_path(base: Path, ref: str) -> Path | None:
    """epic-{ref}.yaml resolved within `base`; None if it escapes (CWE-22)."""
    candidate = (base / f"epic-{ref}.yaml").resolve()
    if not candidate.is_relative_to(base.resolve()):   # py3.9+
        return None
    return candidate
```

**Four call sites, one helper:**

| Site | File:line | Base dir | Ref source |
|------|-----------|----------|-----------|
| merge | `shard_merge.py:62` | `sprint_dir` | parsed sprint YAML |
| orphan-detect | `shard_merge.py:163` | `sprint_dir` | parsed sprint YAML |
| ref_by_id pre-resolve | `ws_push.py:227` | `sprint_dir` | parsed sprint YAML |
| archive loop | `ws_push.py:278` | `archive_dir` | parsed archive YAML |

The two `ws_push.py` sites bypass `merge_epic_shards`, so they import and call `resolve_shard_path` directly.

**Contracts:**
1. A `None` return surfaces the same way the site already handles a missing/bad ref — `warnings.warn` (the module convention) + skip. **Never silent** (#50). Containment and fail-loud land together even in the 1-pt story.
2. `.resolve()` closes the CWE-59 symlink-escape (symlinked shard whose target resolves outside `base` → rejected). Flag this in the PR as inherited coverage, not new scope, so the external reviewer does not double-count it.
3. Fixing at `shard_merge.py:62/:163` inherits containment for **all 6 callers** (ws_push, loader, yaml_io, validator ×2, sprint_yaml hook), not just ws_push.

### 160-12 — Read hygiene, scoped to `ws_push.py`

`ws_push.py:189` is already 160-4-hardened (`encoding="utf-8"` + typed catches + warn + non-dict gate). It is the **template and reuse target** — and it is *also* the `load_file` injected into `merge_epic_shards` at `:232`. The remaining six sites split by shape:

| Shape | Sites | Fix |
|-------|-------|-----|
| YAML read | `:171` index, `:270` archive-file, `:282` archived-shard, `:474/:499/:517` benchmark | Route through a **promoted module-level `_load_yaml_file(path)`** lifted from `_load_file`'s body (encoding + typed catches + warn + non-dict gate). |
| Plain-text read | `:399` persona `agent_name`, `:542` narrative excerpt | Add `encoding="utf-8"` + narrow the enclosing `except Exception` so decode/IO failures surface instead of blanking the panel. |

Promoting `_load_file` consolidates ws_push's entire read story into one hardened function instead of seven hand-rolled `safe_load … except Exception` blocks.

**Do NOT** push read-hygiene into `shard_merge.py` — it owns no reads by design (readers are injected). Keep that boundary.

## Consequences

### Positive

- CWE-22 closed for **all** shard-loading paths via one chokepoint fix; CWE-59 symlink-escape closed as a side effect.
- ws_push read story collapses to one hardened helper (One Truth, One Place); six silent `except Exception` guards become fail-loud.
- 160-4's debugged read logic is reused, not re-authored.
- Each helper is single-responsibility; the dependency-injection contract of `shard_merge` is preserved.

### Negative

- Two helpers in two modules; the "which concern lives where" knowledge is non-obvious (mitigated by this ADR + a comment at the chokepoint).
- `is_relative_to` requires Python 3.9+ (already the project floor).

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Containment rejects a ref silently → trades CWE-22 for a #50 fail-loud violation | Contract #1: `None` return must `warnings.warn` + skip, pinned by test. |
| A second read-helper gets authored in 160-12 instead of promoting `_load_file` | This ADR: promote the one, do not breed a twin. |
| 160-13 and 160-12 both touch `ws_push.py:227/:278` → merge collision | Sequence 160-13 first; 160-12's read sweep then layers on already-contained sites. |
| Symlink-escape coverage counted as new scope by external reviewer | PR notes it as inherited from `.resolve()`, not new work. |

## Implementation Consistency Rules

> For AI agents implementing these stories:

1. **Two helpers, two modules** — `resolve_shard_path` in `shard_merge.py`; `_load_yaml_file` in `ws_push.py`. Never fuse them.
2. **`shard_merge.py` owns no reads** — readers stay injected. Do not add `read_text` there.
3. **Containment returns `Path | None`** — caller warns + skips on `None`. Never silent.
4. **Reuse `_load_file`** — promote it; do not author a second read helper.
5. **Plain-text reads** (`:399`, `:542`) get `encoding=` + narrowed catch, not the YAML helper.
6. **Keep them two stories/PRs** — different CWEs (22 vs 838), different test surfaces, clean independent review.
7. **Sequence 160-13 before 160-12.**

## Sequencing and Scope Fences

**160-13 first, then 160-12.** 160-13 is foundational and touches the shared shard-loading sites at the chokepoint; once contained, 160-12's read sweep layers `encoding=` + surfacing on top with no re-litigation of the same lines.

**Out of scope for both** — name as Delivery Findings so the external reviewer does not read them as misses:
- `loader.py` / `yaml_io.py` read-hygiene (different file; their injected readers are a separate follow-up).
- The `{exc}`-embeds-full-path LOW the 160-4 Reviewer already logged (rounds 1–2).

## Related Decisions

- 160-4 session (`sprint/archive/160-4-session.md`) — origin findings (Reviewer rounds 1–2, lines 79–80) and the `_load_file` prior art this design reuses.
- [ADR-0033: Multi-Repo Worktree Safety](0033-multi-repo-worktree-safety.md) — prior CWE-22 treatment (worktree-name validation) in this codebase.
