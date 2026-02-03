# Dev Agent Gotchas

Lessons learned from debugging sessions.

## Pennyfarthing Installation

**Always use GitHub install:**
```bash
# CORRECT
npm install github:1898andCo/pennyfarthing

# WRONG - not published to npm
npm link pennyfarthing
```

The `pennyfarthing-dist/` directory is committed to repo but not generated during install.

## Symlink Structure

After install, `.claude/` contains symlinks to `node_modules/pennyfarthing/pennyfarthing-dist/`. If commands don't show, reinstall from GitHub.

## Remove Unused Code

When code becomes unused, **delete it immediately**. Don't ask.

## Tool IDs Are Useless

**NEVER show raw `tool_id` / `toolu_*` to users.** Display tool name instead.

## Cyclist Approval Gate

Claude Code's **PreToolUse hooks** are the only way to control tool execution externally. The hook script runs synchronously - Claude Code waits for it.

Key flow:
1. Hook receives tool info via stdin
2. Hook sends HTTP POST to Cyclist
3. Cyclist shows modal if approval needed
4. Hook outputs JSON with `permissionDecision`
5. Claude Code allows/blocks based on decision

## Cyclist Working Directory

**Cyclist must be started from project root**, not from `packages/cyclist/`. The Claude subprocess inherits the working directory, and if started from the wrong place, agents can't access sprint files, session files, or other project resources.

Check with:
```bash
ps aux | grep cyclist  # Look at the cwd
```

If permissions are failing for project files, restart Cyclist from project root.

## Tailing Cyclist Logs

**Dev mode** (running via `just cyclist` or `npm run dev`):
```bash
tail -f /tmp/cyclist.log
```

**Packaged app** (no file logging by default):
```bash
# Kill existing and relaunch with log capture
pkill -f "Cyclist.app"
/Applications/Cyclist.app/Contents/MacOS/Cyclist 2>&1 | tee /tmp/cyclist-live.log
```

Search for errors:
```bash
grep -i -E "(error|warn|exception|fail)" /tmp/cyclist.log | tail -50
```

## Finding Project Root

**Use `.pennyfarthing/` as the marker**, not `pennyfarthing-dist/`.

The `.pennyfarthing/` directory is the most reliable marker - it's created by `pennyfarthing init` in any project using Pennyfarthing, and it exists at the monorepo root for dogfooding too.

`pennyfarthing-dist/` is problematic because:
- It exists as a symlink in `packages/core/` pointing to `../../pennyfarthing-dist`
- `findMonorepoRoot()` would find the symlink first and return wrong path

```typescript
// GOOD: Use .pennyfarthing as marker
if (existsSync(join(dir, '.pennyfarthing'))) {
  return dir;
}

// BAD: pennyfarthing-dist can be a symlink
if (existsSync(join(dir, 'pennyfarthing-dist'))) {
  return dir;  // Might return packages/core/ instead of root!
}
```

---

*Add gotchas discovered during development below*

## Cyclist UI: React is Primary, Vanilla is Deprecated

**React docking workspace is the correct UI system.** The vanilla JS panels in `#container` are deprecated.

Structure:
- `#react-root` → `.cyclist-app` → `.docking-workspace` - **USE THIS**
- `#container` → `#content-area` → legacy panels - **DEPRECATED**

When debugging Cyclist UI issues, focus on the React components in `packages/cyclist/src/public/components/`.

## Shell Standardization: zsh

**Standard:** All Pennyfarthing scripts use `#!/usr/bin/env zsh`, not bash.

If zsh scripts fail to find standard utilities (wc, tr, etc.), the issue is PATH configuration in the user's zsh environment, not the script. Don't change scripts to bash.

## Cyclist: Use Web Mode for Debugging

**For debugging Cyclist UI, use web mode instead of Electron:**

```bash
cd packages/cyclist
CYCLIST_PROJECT_DIR=/path/to/project npm run dev:web
```

This starts an Express server on port 1898 (or next available). Use Playwright to inspect the DOM and debug layout issues.

## Vanilla JS Reference Commit

**Commit `9aea4f371`** is where we removed the legacy vanilla JS implementation.

When asking for "vanilla JS" implementations or REST API fallback patterns, use git pickaxe to find the old code:
```bash
git show 9aea4f371^:packages/cyclist/src/public/js/<filename>.js
```

Key files that had REST fallback:
- `components/SettingsPanel.js` - Theme picker with `/api/settings` fallback
- `progress-panel.js` - Todos panel (Electron-only, no REST)
- `sidebar/settings.js` - Settings load/save

Example pattern from vanilla JS:
```javascript
// Try IPC first, then HTTP fallback
if (window.electronAPI?.settings?.get) {
  settings = await window.electronAPI.settings.get();
} else {
  const response = await fetch('/api/settings');
  if (response.ok) settings = await response.json();
}
```

## Tailwind v4: Use `@import "tailwindcss"` Not `@tailwind` Directives

**Cyclist uses Tailwind v4.** The old v3 syntax (`@tailwind base; @tailwind components; @tailwind utilities;`) does NOT work correctly with v4's tree-shaking.

```css
/* WRONG - Tailwind v3 syntax, causes styles to be tree-shaken */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* CORRECT - Tailwind v4 syntax */
@import "tailwindcss";
```

Custom CSS classes written after `@import "tailwindcss"` will be preserved. With the old syntax, custom classes may be silently removed during build even if they're used in components.

## Electron Mode vs Web Mode: Two ClaudeService Instances

**CRITICAL:** After IPC-to-WebSocket migration, React components use WebSocket (`/ws/claude`).

In **web mode**, each WebSocket connection creates its own `ClaudeService` subprocess - this is correct.

In **Electron mode**, the main process (`main.ts`) manages the ClaudeService. The WebSocket endpoint must NOT create a separate ClaudeService or messages won't reach the React UI.

**Solution:** Bridge main process messages to WebSocket clients:

```typescript
// websocket.ts - detect mode and track clients
const isElectronMode = process.env.CYCLIST_ELECTRON_MODE === '1';
const claudeClients = new Set<WebSocket>();

// In Electron mode, don't create ClaudeService per connection
if (isElectronMode) {
  claudeClients.add(ws);  // Just track for broadcast
} else {
  // Web mode: create ClaudeService per connection
}

// main.ts - broadcast to WebSocket alongside IPC
broadcastToRenderer(IPC_CLAUDE_CHANNELS.CLAUDE_MESSAGE, message);
broadcastClaudeMessage(message);  // Also send to WebSocket clients
```

**Environment variable:** `CYCLIST_ELECTRON_MODE=1` is set by main.ts before server starts.

## WebSocket Callback Bridge Pattern (Electron Mode)

When WebSocket handlers need to call main process functions, use callback registration to avoid circular imports:

```typescript
// websocket.ts - define and export callback setters
type ClaudeSendCallback = (prompt: string, images: PastedImage[],
  onMessage: (msg: unknown) => void,
  onComplete: () => void,
  onError: (err: string) => void) => void;

let claudeSendCallback: ClaudeSendCallback | null = null;

export function setClaudeSendCallback(callback: ClaudeSendCallback): void {
  claudeSendCallback = callback;
}

// In WebSocket handler
if (isElectronMode && claudeSendCallback) {
  claudeSendCallback(msg.prompt, msg.images || [], onMessage, onComplete, onError);
}

// main.ts - register callbacks in startProjectWatchers()
setClaudeSendCallback(async (prompt, images, onMessage, onComplete, onError) => {
  const service = getClaudeService();
  for await (const message of service.sendMessage(prompt, { images })) {
    onMessage(message);
  }
  onComplete();
});
```

This pattern:
- Avoids circular imports (websocket.ts doesn't import main.ts)
- Keeps ClaudeService singleton in main.ts
- Allows WebSocket to trigger main process functions

## REST API Identity Must Include avatarUrl

The `/api/identity` endpoint returns `{ jiraEmail, githubUsername }`. But `useUserAvatar` expects `avatarUrl`.

**Fix:** Construct avatar URL from username:
```typescript
avatarUrl: githubUsername ? `https://avatars.githubusercontent.com/${githubUsername}` : null
```

## Playwright MCP + Electron: Requires CDP + Internal URL

**Playwright MCP cannot connect directly to Electron apps.** It starts its own Chromium browser.
The workaround uses CDP to discover the Electron app's internal server URL.

### Step 1: Enable CDP

Electron apps must be started with `--remote-debugging-port=9222`:

```bash
# Direct (from packages/cyclist directory)
CYCLIST_PROJECT_DIR=/path/to/project npx electron --remote-debugging-port=9222 dist/main.js

# Via justfile (if cdp flag configured)
just cyclist here cdp

# Via npm script (add to package.json)
"dev:cdp": "electron --remote-debugging-port=9222 dist/main.js"
```

### Step 2: Get Internal Server URL

```bash
# Get the page list (includes internal server URL)
curl -s http://localhost:9222/json/list
```

Response includes the internal URL:
```json
[{
  "title": "Cyclist - Claude Code Dashboard",
  "url": "http://localhost:60178/",  # <-- Use THIS URL
  "webSocketDebuggerUrl": "ws://localhost:9222/devtools/page/..."
}]
```

### Step 3: Connect Playwright to Internal URL

```
mcp__playwright__browser_navigate to http://localhost:60178/
```

**The port changes each launch** - always check `/json/list` first.

### Common Mistakes

1. **Navigating to `http://localhost:9222`** - Shows CDP index page, not your app
2. **Expecting Playwright to use `connectOverCDP`** - MCP doesn't support this
3. **Empty `/json/list` response** - App failed to start (check for "Not a Pennyfarthing project" errors)

### Environment Variable for Project Directory

When running Electron directly (not via justfile), set `CYCLIST_PROJECT_DIR`:

```bash
CYCLIST_PROJECT_DIR=/Users/you/Projects/your-project npx electron --remote-debugging-port=9222 dist/main.js
```

Without this, Cyclist may fail with "Not a Pennyfarthing project" if `.pennyfarthing/` isn't in the working directory.

See: `interactive-debug` workflow step-01-connect for full detection logic.
