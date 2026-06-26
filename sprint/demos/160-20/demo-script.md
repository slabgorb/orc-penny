**Total runtime: ~8 minutes**

---

**Slide 1 — Title (0:00–0:30)**
Open with the slide. Introduce the story as a "silent failure" fix — the kind of bug that's dangerous precisely because it produces no errors, just wrong answers.

---

**Slide 2 — Problem (0:30–2:00)**
Walk through the problem statement. Emphasize the trust gap: a developer sees a "0 dead code files" report and believes their codebase is clean. In reality, the analysis never ran.

**Live terminal demo (1:15–2:00):**
```bash
pf frame start
# In a second pane:
curl -s http://localhost:8765/api/analysis/dead-code | jq .
```
Show the audience the response: an empty list `[]` or a raw coroutine string like `<coroutine object find_stale_files at 0x...>`. Point out there's no error — just silence.

*Fallback if Frame won't start: show Slide 2 and describe the output verbally using the coroutine string example.*

---

**Slide 3 — What We Built (2:00–4:00)**
Walk through "What Changed." Use the sticky-note analogy. This is the ELI5 slide — keep it light.

**Live code diff (2:30–3:30):**
```bash
git diff HEAD~1 -- pennyfarthing/pennyfarthing-dist/src/pf/frame/routes/brownfield.py
```
Point to the three `await` additions. Each diff hunk is a one-word change. Say: "This is the entire fix. Three words across three lines."

*Fallback: show the Before/After slide instead.*

---

**Slide 4 — Why This Approach (4:00–5:00)**
Cover the engineering reasoning. The key message: minimal, targeted fix. No over-engineering.

---

**Before/After slide (5:00–6:00)**
Walk through the comparison table. Before: function returns a coroutine object, analysis never executes, result is empty or garbage. After: function awaits the coroutine, analysis runs fully, result contains real data.

**Live confirmation (5:30–6:00):**
```bash
curl -s http://localhost:8765/api/analysis/dead-code | jq 'length'
```
Show a non-zero count — real files identified as stale. Compare to the earlier empty `[]`.

*Fallback: show the Before/After slide and read the concrete values aloud.*

---

**Roadmap slide (6:00–7:00)**
Connect this fix to the broader fail-loud sweep (stories 160-17 through 160-20). Frame it as: we're making the system honest — when something doesn't work, it says so.

---

**Questions (7:00–8:00)**

---