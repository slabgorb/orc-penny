---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-11: Type OTLP Receiver Payloads Properly

## Business Context

The OTLP receiver is a high-traffic ingest path: every token usage metric and every tool execution event arriving from Claude Code passes through it. Two `as any` casts in `packages/core/src/server/otlp-receiver.ts` suppress TypeScript's ability to catch shape mismatches at compile time. The cyclist package (`packages/cyclist/src/otlp-receiver.ts`) already has fully-typed OTLP payload interfaces (`OTLPPayload`, `OTLPLogsPayload`, their nested structures) that handle the exact same wire format. The core version was written quickly during Story 98-23 to stand up standalone processing and never received the same typing treatment. Eliminating these casts closes the gap, makes the payload shapes self-documenting, and ensures future changes to the OTLP parsing logic are checked by the compiler under `strict: true`.

## Technical Guardrails

**Primary file to change:**
- `pennyfarthing/packages/core/src/server/otlp-receiver.ts` — the only file with `as any` casts (lines 243, 251, 279)

**Reference implementation (do not modify):**
- `pennyfarthing/packages/cyclist/src/otlp-receiver.ts` — already has typed interfaces for the same OTLP wire format; use as the source of truth for shape names and field types

**Existing tests (must pass, no changes to test file needed):**
- `pennyfarthing/packages/core/src/server/otlp-receiver.test.ts`

**TypeScript config:** `pennyfarthing/tsconfig.base.json` has `"strict": true`. The `eslint-disable @typescript-eslint/no-explicit-any` block at lines 239–449 of the core file suppresses the linter; removing the casts means the eslint-disable wrapper can be removed too.

**Build command:** `cd pennyfarthing/packages/core && pnpm run build`

**Test command:** `cd pennyfarthing/packages/core && npm test`

**Key constraint:** `as any` inside `parseOTLPMetrics` at line 251 is inside a `find()` callback — the fix is making the outer `payload` typed so the callback parameter is inferred, not adding an inline annotation to the callback alone.

## Scope Boundaries

**In scope:**
- Define typed interfaces for the OTLP metrics payload shape in `packages/core/src/server/otlp-receiver.ts` (can mirror cyclist's `OTLPAttribute`, `OTLPDataPoint`, `OTLPMetric`, `OTLPScopeMetrics`, `OTLPResourceMetrics`, `OTLPPayload`)
- Define typed interfaces for the OTLP logs payload shape (mirror cyclist's `OTLPLogAttribute`, `OTLPLogRecord`, `OTLPScopeLogs`, `OTLPResourceLogs`, `OTLPLogsPayload`)
- Replace `const payload = body as any` in `parseOTLPMetrics` with `const payload = body as OTLPPayload`
- Replace `const payload = body as any` in `parseOTLPLogs` with `const payload = body as OTLPLogsPayload`
- Remove the `(a: any)` annotation from the `.find()` callback inside `parseOTLPMetrics` (becomes unnecessary once `payload` is typed)
- Remove the `/* eslint-disable @typescript-eslint/no-explicit-any */` and `/* eslint-enable */` wrapper lines (239 and 449) once all `any` casts are gone
- Verify `pnpm run build` passes with no TypeScript errors
- Verify existing tests in `otlp-receiver.test.ts` pass without modification

**Out of scope:**
- Changes to `packages/cyclist/src/otlp-receiver.ts` — it is already correctly typed
- Extracting the interfaces into a shared package — that is a larger refactor not part of this story
- Adding new tests — the existing test suite provides coverage; this is a type-only change
- Changing any runtime behavior — the logic inside `parseOTLPMetrics` and `parseOTLPLogs` must remain identical
- Story 141-12 (UI component type assertions) — separate story

## AC Context

**AC1: TypeScript interfaces defined for OTLP metric and log payloads**

The interfaces to define in core's `otlp-receiver.ts` mirror the cyclist version exactly. For metrics:

```typescript
interface OTLPAttribute {
  key: string;
  value: { stringValue?: string; intValue?: number };
}

interface OTLPDataPoint {
  asInt?: number;
  asDouble?: number;
  attributes?: OTLPAttribute[];
}

interface OTLPMetric {
  name: string;
  sum?: { dataPoints?: OTLPDataPoint[] };
}

interface OTLPScopeMetrics {
  metrics?: OTLPMetric[];
}

interface OTLPResourceMetrics {
  scopeMetrics?: OTLPScopeMetrics[];
}

interface OTLPMetricsPayload {
  resourceMetrics?: OTLPResourceMetrics[];
}
```

For logs:

```typescript
interface OTLPLogAttribute {
  key: string;
  value: { stringValue?: string; intValue?: number; boolValue?: boolean };
}

interface OTLPLogRecord {
  timeUnixNano?: string;
  body?: { stringValue?: string };
  attributes?: OTLPLogAttribute[];
}

interface OTLPScopeLogs {
  logRecords?: OTLPLogRecord[];
}

interface OTLPResourceLogs {
  scopeLogs?: OTLPScopeLogs[];
}

interface OTLPLogsPayload {
  resourceLogs?: OTLPResourceLogs[];
}
```

All fields are optional (matching real-world OTLP JSON where nested keys may be absent) and all primitive value variants are typed (string/int/bool), matching the three-branch extraction logic already present in both `parseOTLPMetrics` and `parseOTLPLogs`.

**AC2: All `as any` casts in `otlp-receiver.ts` replaced with typed alternatives**

Three casts to eliminate:

1. `parseOTLPMetrics` line 243: `const payload = body as any` → `const payload = body as OTLPMetricsPayload`
2. `parseOTLPMetrics` line 251: `dp.attributes?.find((a: any) => a.key === 'type')` → once `payload` is typed as `OTLPMetricsPayload`, `dp` is inferred as `OTLPDataPoint`, `a` is inferred as `OTLPAttribute`, and the `: any` annotation is removed
3. `parseOTLPLogs` line 279: `const payload = body as any` → `const payload = body as OTLPLogsPayload`

After the fix, the `eslint-disable @typescript-eslint/no-explicit-any` block wrapper (lines 239 and 449 in the current file) can be removed entirely because no `any` uses remain in that region.

**AC3: Build passes with strict type checking**

The monorepo root `tsconfig.base.json` enables `"strict": true` which activates `noImplicitAny` among other checks. Run `pnpm run build` from `packages/core/` and confirm zero TypeScript errors. The change is purely additive (new interfaces + narrower cast types), so no existing call sites or return types change.

**AC4: Existing tests pass**

Run `npm test` from `packages/core/`. The `otlp-receiver.test.ts` file contains ACs 1–8 from Story 98-23 plus the Story 132-5 enrichment pipeline suite — all 30+ assertions must remain green. No modifications to the test file are needed or expected; this story changes only the type-level declarations, not runtime logic.
