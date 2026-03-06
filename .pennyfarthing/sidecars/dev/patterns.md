# Dev Agent Patterns

<pattern name="paths">
Always use `$CLAUDE_PROJECT_DIR` as base. Multi-repo: `source $CLAUDE_PROJECT_DIR/scripts/repo-utils.sh`.
</pattern>

<pattern name="assessment">
```
## Dev Assessment
**Implementation Complete:** Yes
**Files Changed:** `path` - description
**Tests:** N/N passing (GREEN)
**PR:** #N — title
**Handoff:** To Reviewer for code review
```
</pattern>

<pattern name="self-dev">
`.claude/` dirs are symlinks to `pennyfarthing-dist/`. Edit source, changes are immediate.
</pattern>

<pattern name="pf-init-impact">
**Self-review addendum:** Before handoff, check if any changed files affect
`pf init` / project setup. Files in `pennyfarthing-dist/` are distributed to
consumer projects. Ask yourself:

- Will this overwrite project-local customizations on next `pf init` or upgrade?
- Does this add new files that should be seeded once but never overwritten?
- Are config/gate/schema changes backwards-compatible with existing installs?
- Do project-local overrides (`.pennyfarthing/gates/`, `.pennyfarthing/config.local.yaml`)
  still take precedence after this change?

If any answer is "no" or "unsure", flag it as a Delivery Finding before exit.
</pattern>

<pattern name="notifications">
Message view IS the notification system. Errors to `console.error`, no toast UI.
</pattern>

<pattern name="yaml-rw">
Read-modify-write YAML. Never overwrite entire file to set one field.
```typescript
let existing = fs.existsSync(path) ? parseYaml(fs.readFileSync(path, 'utf-8')) : {};
existing.field = newValue;
fs.writeFileSync(path, stringifyYaml(existing));
```
</pattern>

<pattern name="electron-storage">
Use `path` option for per-project storage: `windowStateKeeper({ path: join(projectDir, '.pennyfarthing') })`.
</pattern>
