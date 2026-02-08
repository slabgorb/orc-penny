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
