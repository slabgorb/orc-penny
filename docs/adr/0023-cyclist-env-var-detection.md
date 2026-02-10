# ADR-0023: Cyclist Detection via Environment Variable

## Status: Accepted

## Context

The `is_cyclist_running()` function in `pennyfarthing_scripts/hooks.py` is called on every PreToolUse hook invocation to determine whether the Claude process is running inside Cyclist (the visual terminal) or standalone CLI mode. This gate controls whether hook requests are sent to WheelHub for approval or deferred to Claude Code's built-in permission system.

### The Problem

The original implementation checked for `.cyclist-port` file existence:

```python
def is_cyclist_running(project_root):
    return (root / ".cyclist-port").exists()
```

This produced **false positives in CLI mode** when:
- Cyclist shut down without cleanup (crash, SIGKILL, forced close)
- The Electron process was killed but port file persisted
- A previous Cyclist session left a stale `.cyclist-port` file

False positives caused CLI-mode hooks to attempt HTTP requests to a dead WheelHub server, adding latency and error noise on every tool invocation.

### Approaches Considered

| Approach | Mechanism | Latency | Stale-Proof | Complexity |
|----------|-----------|---------|-------------|------------|
| **Port file** (original) | `Path.exists()` | ~0.1ms | No | Low |
| **PID file + signal** | Read `.cyclist-pid`, `os.kill(pid, 0)` | ~0.2ms | Mostly | Medium — requires PID lifecycle management on both TS and Python sides, edge cases (recycling, permissions) |
| **HTTP health check** | `GET /api/health` | 5-50ms | Yes | Low — but unacceptable latency per hook invocation |
| **Environment variable** | `os.environ.get()` | ~0ns | Yes | Lowest — already set, dies with process |

### What Already Exists

`ClaudeService.spawn()` in `packages/cyclist/src/claude-service.ts:443` already sets `CYCLIST: '1'` in the environment of every Claude process spawned by Cyclist:

```typescript
const env = { ...process.env, ...this.defaultEnv, ...options?.env, CYCLIST: '1', PATH: augmentedPath };
```

This env var has been present since the original ClaudeService implementation. It was used informally but never formalized as the canonical detection mechanism.

## Decision

Replace file-based Cyclist detection with environment variable check:

```python
def is_cyclist_running(project_root=None):
    return os.environ.get("CYCLIST") == "1"
```

The `CYCLIST=1` environment variable is the canonical signal for "this Claude process is running inside Cyclist."

### Why This Works

1. **Inherently process-scoped.** Env vars die with the process. No stale state possible.
2. **Zero I/O.** Dictionary lookup in the process's own memory. No filesystem, no network.
3. **Already deployed.** `ClaudeService` has set `CYCLIST=1` since its creation. No TS-side changes needed.
4. **Unforgeable by stale files.** A crashed Cyclist can leave `.cyclist-port` on disk, but it cannot inject env vars into a CLI-mode process started independently.

### What This Does NOT Change

- `.cyclist-port` file is still written and used for **port discovery** by `get_cyclist_port()` — hooks that pass the `is_cyclist_running()` gate still need to know which port to talk to.
- `.cyclist-pid` file is still written by the `process-spawned` event for **Claude process lifecycle tracking** (Story B-24) — unrelated to Cyclist detection.
- Shell scripts that check `.cyclist-port` are unaffected — they run outside the Claude process and need file-based discovery. The false-positive issue only affected Python hooks running inside the Claude process.

## Consequences

### Positive

- **Eliminates false positives.** CLI mode will never see `CYCLIST=1` regardless of stale files on disk.
- **Simpler code.** One-liner replacement, no PID lifecycle to manage.
- **Faster.** Env var lookup is a hash table read; no syscalls.
- **No TS changes required.** The env var was already being set.

### Negative

- **Cannot detect Cyclist from outside the Claude process.** External tools (shell scripts, other Python scripts not spawned by Cyclist) cannot use this method. They must continue using `.cyclist-port` file checks. This is acceptable because the false-positive bug only affected in-process hooks.
- **`project_root` parameter becomes vestigial.** Kept for backward compatibility but no longer used by `is_cyclist_running()`. Could be removed in a future cleanup.

### Pattern Established

**For future in-process detection needs:** Check `CYCLIST` env var, not port files. Port files are for port _discovery_, not process _detection_.

## Related

- **Story:** MSSCI-14722 (98-8)
- **PR:** #789
- **ADR-0004:** WheelHub consolidation (established port file pattern, now partially superseded for detection)
- **Files:** `pennyfarthing_scripts/hooks.py`, `packages/cyclist/src/claude-service.ts`
