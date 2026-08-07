# Demo Script — 162-49

**Total time: ~5 minutes**

**Scene 1 — Title (0:00–0:30) | Slide 1**
Open on the title slide. "Today we're talking about a silent production break we found and fixed in the persona routing layer — and the test gap that was hiding it."

**Scene 2 — The Problem (0:30–2:00) | Slide 2**
Describe the broken state without live code. "Imagine you have two departments that need to hand off a file. Department A writes on the label: *'Folder path, then session ID.'* Department B's intake form says: *'Agent name, then optionally a folder path.'* The handoff fails every time — but only when someone actually tries to do it live."

Point out: "Our automated tests were running from a specific folder on disk. From that folder, the system returned a 'not found' before it ever reached the broken handoff. Tests: green. Production: broken."

If asked for specifics: "The test suite reported 6,123 passing tests from one directory, 6,119 passing and 4 failing from another. Same code, different working directory."

**Scene 3 — What We Fixed (2:00–3:30) | Slide 3**
"We corrected the function call to pass the right arguments in the right order — agent name first, project root second. We also added a test fixture called `PF_PROJECT_DIR` that anchors the test suite to a consistent project directory so results are the same no matter where you run the tests from."

*Live demo (optional — if environment is available):*
```bash
# Show the test suite running from two directories — now identical counts
cd pennyfarthing-dist && pf test run test_frame_routes
cd /tmp && pf test run test_frame_routes
# Both should now report the same passing count
```
*Fallback if demo fails: go to Slide 5 (Before/After) showing the 6123/0 vs 6119/4 numbers.*

**Scene 4 — Why This Approach (3:30–4:30) | Slide 4**
"We fixed the bug and the blind spot at the same time. A test suite that gives different answers depending on where you run it is a liability — it erodes trust in the green light. This change makes the suite honest."

**Scene 5 — Wrap (4:30–5:00) | Slide 6 (Roadmap) → Slide 7 (Questions)**
"This is part of a broader push to harden the test harness so our pipeline catches what it's supposed to catch. Questions?"

---
