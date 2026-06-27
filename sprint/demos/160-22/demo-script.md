**Total estimated time: 8–10 minutes**

---

**[Slide 1 — Title] 0:00–0:30**
Open on the title slide. Introduce the talk as a "small fix with a big security surface." Set the tone: this is about defense-in-depth, not a breach response.

---

**[Slide 2 — Problem] 0:30–2:30**
Walk through the problem with a concrete example. Say something like:

> "If I asked the app 'what project is open?', it used to respond with something like `/Users/alice/clients/acme/pennyfarthing`. That one line tells a curious observer: the OS is macOS or Linux, the username is `alice`, she works with a client called `acme`, and the project is `pennyfarthing`."

**Live demo option** (if environment is available):
```bash
curl -s http://localhost:7821/api/project_info | jq '.project_dir'
# BEFORE: "/Users/alice/clients/acme/pennyfarthing"
# AFTER:  "pennyfarthing"
```
**Fallback:** Show the "Before/After" slide instead.

---

**[Slide 3 — What We Built] 2:30–5:00**
Walk through the two specific fixes:

1. **Project info leak** — show the before/after for `get_project_info`:
   - Before: `"project_dir": "/Users/alice/Work/pennyfarthing"`
   - After: `"project_dir": "pennyfarthing"`

2. **Git file listing leak** — show the before/after for `get_git_all`:
   - Before: paths like `src/pf/frame/data_proxy.py` returned verbatim
   - After: paths sanitized or omitted from the response body

**Live demo option:**
```bash
curl -s http://localhost:7821/api/git_all | jq '.files[0]'
```
Show the sanitized output.

**Fallback:** Show static before/after slide with the two JSON snippets side by side.

---

**[Slide 4 — Why This Approach] 5:00–6:30**
Keep this brief. The key message: "We removed what wasn't needed rather than obscuring it." Use the hotel key card analogy from the "What Changed" section.

Emphasize that story 160-19 (error message sanitization) and this story (160-22) together close an entire class of information-disclosure findings that the security reviewer surfaced in a single audit pass. This is the last piece.

---

**[Roadmap slide] 6:30–8:00**
Connect to broader initiative (see Roadmap section below). Mention that the reviewer pipeline found these proactively — no user report, no incident.

---

**[Questions] 8:00–10:00**
Open floor.

---