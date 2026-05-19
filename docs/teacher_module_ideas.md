# Teacher Module — Ideas & Planning

## Option A: Built into Clefira (Teacher Dashboard)

**Student Tracker Module** — a new section (like Learning Mode) toggled by a `TEACHER_MODE_ENABLED` flag.

### What it could track per student:
- **Repertoire log** — piece name, composer, date assigned, date completed, rating (1-5 stars), notes ("needs work on measure 12-16 dynamics")
- **Scales checklist** — grid of all major/minor scales, mark as: not started / working / comfortable / mastered. Track hands separate/together, tempo achieved
- **Arpeggios** — same grid approach, root position + inversions
- **Sight reading level** — auto-populated from Clefira's sight reading scores if the student uses the app
- **Ear training progress** — auto-populated from interval/chord training data
- **Lesson notes** — free text per session with date stamp
- **Practice goals** — "this week: Minuet in G mm. 1-16 hands together at 60bpm"

### Why inside Clefira:
The ear training and sight reading data is already there. A teacher tab could show the student's actual accuracy trends, weak intervals, note reading speed — data you can't get from a paper notebook.

### Risk:
Scope creep. The app becomes two things at once.

---

## Option B: Separate Companion App (Clefira Teacher)

A lightweight standalone app (or even a web app) purely for lesson management.

### Core features:
- **Student roster** — name, age, level, instrument, lesson day/time
- **Lesson log** — per-student session diary: date, what was covered, what to practice
- **Repertoire tracker** — per-student list of pieces with status (assigned / in progress / polished / performed)
- **Skill matrix** — scales, arpeggios, technique items in a grid with progress markers
- **Practice assignments** — generate a weekly practice sheet the student/parent can view
- **Progress reports** — monthly summary you can share with parents ("Johnny mastered C and G major scales, working on F major. Sight reading improved from 65% to 82%.")

### Sync with Clefira:
If the student uses Clefira on their own device, their practice data could sync to the teacher's dashboard via a simple code/QR pairing.

---

## Option C: Hybrid — Studio Management

Beyond just tracking, a full piano studio tool:

- **Scheduling** — lesson calendar with recurring slots
- **Billing** — track payments, generate invoices
- **Recital planning** — program builder, student assignments
- **Parent communication** — share practice goals and progress notes
- **Library** — your method book inventory, which student has which book

This is a separate product entirely (competitors: My Music Staff, Tonara, Fons).

---

## Recommendation

**Start with Option A as a hidden module inside Clefira.**

### Reasons:
1. **Data layer already exists** — `module_progress.gd` pattern (JSON save/load) works for student records
2. **Ear/sight data is already tracked** — connecting it to a student profile is straightforward
3. **One app to maintain** — no separate deployment, no sync protocol
4. **Natural upsell** — "Clefira Pro for Teachers" could be the monetization path for v2.0
5. **Fast to prototype** — a simple list view + text fields + a skill grid, using the same UI patterns already in place

### Killer feature:
The student's actual practice data feeds directly into the teacher's view. You don't have to ask "did you practice scales this week?" — you can see their accuracy trend. No competitor has this.
