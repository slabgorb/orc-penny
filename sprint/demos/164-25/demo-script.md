# Demo Script — 164-25

**Total runtime: ~8 minutes**

---

**[0:00–0:45] — Slide 1: Title**
Open with: "Today we're closing a category of silent failures in the Frame analysis API — routes that looked healthy but were broken underneath."

---

**[0:45–2:00] — Slide 2: Problem**
Walk through the problem with the delivery driver analogy. Point to the three affected routes: `/hotspots`, `/health-score`, `/code-markers`. Say: "Before this fix, calling any of these would either return a 500 error or silently fail — and our test suite was configured to accept a 500 as a passing result, so it was invisible."

*If live demo available:*
```bash
# Show the old broken behavior (if running against pre-fix branch)
curl -X POST http://localhost:8765/api/frame/hotspots \
  -H "Content-Type: application/json" \
  -d '{"project": "pennyfarthing", "path": "/path/to/project"}'
# Expected pre-fix: 500 Internal Server Error or TypeError in logs
```
*Fallback: Show Slide 2 with the error message screenshot.*

---

**[2:00–3:30] — Slide 3: What We Built**
"We fixed the argument mismatch in two routes, removed a nonexistent parameter from a third, added proper path handling, and hardened the test suite to catch this class of bug going forward."

*Live demo (post-fix):*
```bash
# Hotspots — now returns correct data
curl -X POST http://localhost:8765/api/frame/hotspots \
  -H "Content-Type: application/json" \
  -d '{"project": "pennyfarthing", "path": "/Users/keithavery/Projects/op-1/pennyfarthing"}'
# Show: 200 OK, JSON with file hotspot list

# Health score — use_cache kwarg removed, now clean
curl -X POST http://localhost:8765/api/frame/health-score \
  -H "Content-Type: application/json" \
  -d '{"project": "pennyfarthing", "path": "/Users/keithavery/Projects/op-1/pennyfarthing"}'
# Show: 200 OK, score object (e.g. {"score": 84, "grade": "B"})
```
*Fallback: Show Before/After slide.*

---

**[3:30–4:30] — Slide 4: Why This Approach**
"We followed the same pattern we established in 160-20 rather than inventing a new one. Consistency matters — every async route in Frame now uses the same threading shape, which makes future debugging faster."

---

**[4:30–5:30] — Before/After Slide**
Walk through the comparison table. Emphasize: "The test fix is as important as the code fix. We closed the inspection gap."

---

**[5:30–6:30] — Roadmap Slide**
Connect to upcoming Frame dashboard work. "These three routes now feed reliable data into the analysis panels — which unblocks the UI work planned for the next sprint."

---

**[6:30–8:00] — Questions**

---
