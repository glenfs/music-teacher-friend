# Teacher Module Audit — 25 Improvement Recommendations

Saved 2026-05-17. Source: post-implementation audit pass after adding lesson-log
edit + delete + schema versioning.

Status legend:
- ✅ Implemented (this session or earlier)
- 🟡 Planned for current batch
- ⏸️ Deferred — needs design discussion before implementation
- 🔭 Bigger build, worth its own session

---

## High-impact gaps

1. **🟡 Sort logs by date, not insertion order**
   `add_lesson_log_entry` does `log.insert(0, ...)` — newest-added wins, but a
   backdated entry still goes to the top. Sort by `entry.date` descending on
   display so chronological order matches reality.

2. **⏸️ Data export**
   No way to extract student records for backup, parent sharing, device transfer.
   Decisions needed: JSON-only or also CSV/HTML? Whole-archive or per-student?
   Where does the file go on Android (storage permissions)?

3. **⏸️ Data import**
   Same problem in reverse. If a teacher loses their device, no restore path.
   Tied to #2 — usually the same session.

4. **🔭 Bulk operations**
   Can't delete a student, can't archive an inactive student, can't delete
   multiple logs at once. Needs multi-select UI design.

5. **🟡 Search / filter on logs**
   ~24+ entries per student per term is unmanageable without filter by date
   range, text search of summary, or filter by tag.

6. **⏸️ Richer lesson log fields**
   Currently 4 free-text fields. Real lesson logs need: pieces worked on (link
   to `current_pieces`), duration, attendance, skill tags, separate parent
   notes. Schema bloat risk — needs scope decision.

## Medium-impact

7. **🟡 "Duplicate previous log" quick template**
   Teachers often type similar text weekly. Lets them dupe + edit instead of
   re-typing.

8. **⏸️ Student notes panel**
   Persistent "About this student" (allergies, learning style, parent contact,
   grade level) separate from per-lesson logs.

9. **⏸️ Multi-teacher support**
   Single shared `teacher_data.json` — fine for single tutor, not for a school
   with multiple teachers sharing one tablet. Needs identity/auth model.

10. **⏸️ PIN protection on Teacher mode**
    Student records contain personal info. 4-digit PIN gate stored hashed?
    Biometric? No protection?

11. **🟡 Auto-surfaced student practice data from module_progress**
    Teacher view shows manual logs but NOT what student practiced in the app
    between lessons. Data is all there in `module_progress.gd` — huge missed
    opportunity, easy plumbing.

12. **⏸️ In-flow confirm instead of ConfirmationDialog**
    Native dialog feels out-of-place on Android tablets. Consider tap-again
    pattern for UI consistency.

13. **🟡 Today's lessons agenda view**
    No "who's coming next, what to focus on" quick view. Filter logs where
    `next_focus` is non-empty from previous sessions.

## Low-impact polish

14. **🟡 Undo for delete**
    Once confirmed, the entry's gone. Add a 5-second "Undo" toast.

15. **⏸️ Keyboard shortcuts**
    Edit form has Save/Cancel buttons but no Ctrl+S / Esc shortcuts. Desktop
    users expect them.

16. **🟡 Edit-scroll preservation**
    Refreshing content reflows from top, losing scroll position mid-edit.

17. **🔭 Drag-reorder for current_pieces**
    Pieces list renders in insertion order. Teachers want to mark "current
    focus piece" by reordering.

18. **⏸️ Avatar or color tag per student**
    Visual distinction when scanning a roster. Built-in icons vs photo upload?

19. **🟡 Lesson count stat**
    "Sarah, 12 lessons this term, started Jan 5." Helps end-of-term review.

20. **⏸️ CSV/HTML term report export per student**
    Emailable summary for parents. Needs format/template design.

## Architectural / data-safety

21. **⏸️ Schema migration tests**
    Hook exists but no tests. Add unit test loading historical versions and
    verifying migration output. Catches regressions.

22. **🟡 Auto-backup rotation**
    `.corrupt.<timestamp>` only catches corruption. Rotate-keep-last-3 manual
    backups for safety.

23. **🔭 Multi-device conflict detection**
    Two devices editing same file → last-write-wins silently. Not a concern
    for single-device users.

24. **🔭 Per-student files OR SQLite**
    Inline lesson logs fine for hundreds; slow for thousands. Architectural
    change for long-term scale.

25. **🟡 Workflow analytics**
    "You added 4 lesson logs this week" — nudges consistent record-keeping.

---

## Implementation order from current batch (this session)

1. Sort logs by date (#1)
2. Auto-surfaced student practice data (#11) — biggest pedagogical win
3. Search/filter logs (#5)
4. Duplicate previous log (#7)
5. Today's agenda view (#13)
6. Undo-delete toast (#14)
7. Lesson count + week stats (#19, #25)
8. Auto-backup rotation (#22)
9. Edit-scroll preservation (#16)

Estimated: ~1500 lines, one focused session.

## Design-discussion items (handle next round)

- #2/#3 export/import
- #6 richer log fields
- #8 student notes panel
- #10 PIN protection
- #18 avatars
- #20 reports
- #12 in-flow confirm

## Bigger builds (separate session each)

- #4 bulk operations
- #9 multi-teacher
- #17 drag-reorder pieces
- #20 (if HTML reports become a feature)
- #21 schema migration tests
- #23/#24 multi-device / SQLite migration
