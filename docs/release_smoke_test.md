# Clefira Desktop Release — Manual Smoke Test Checklist

Run this on a **clean Windows machine** (or at minimum: rename your existing `%APPDATA%\Godot\app_userdata\Clefira\` folder so the app sees a first-launch state) before every release.

Mark each check as ✓ or ✗ with a note for any failures.

---

## 0. Pre-test prep

- [ ] Latest export built from `export_presets.cfg` → `builds/windows/teacher/ClefiraTeacher.exe` and `builds/windows/student/ClefiraStudent.exe`
- [ ] Either: rename existing user data dir to simulate first launch, **or** test on a machine that's never run Clefira
- [ ] Have a USB MIDI keyboard handy (optional but covers MIDI path)
- [ ] Have a microphone available (covers Mic Mode + Sight Singing paths)

---

## 1. First launch — Terms acceptance

- [ ] Splash plays, then **Welcome to Clefira** modal appears
- [ ] "View Terms" button opens `EULA.html` in default browser, content is readable, no broken styling
- [ ] "View Privacy Policy" button opens `PRIVACY.html` in default browser
- [ ] "Accept & Continue" button is the only path forward — clicking it dismisses and proceeds
- [ ] Re-launching the app does NOT show the terms modal again
- [ ] `ear_settings.json` has `"terms_accepted_version": 1`

## 2. Student Edition — first-run profile prompt

(Only if testing the Student build)

- [ ] After terms accept, the Welcome profile prompt appears
- [ ] Name + Level fields work; "Save & Start" persists and proceeds
- [ ] "Skip" also proceeds; doesn't re-prompt next launch
- [ ] Home menu shows student name in subtitle

## 3. Teacher Edition — first-run onboarding

- [ ] After terms accept, home menu loads (no separate profile prompt)
- [ ] Active-student chip says "(pick a student)"
- [ ] Open Teacher Dashboard from home → sidebar shows **Welcome to Clefira** card
- [ ] "Load sample studio (2 demo students)" creates Sarah + Daniel with populated tabs
- [ ] Sarah's Overview tab shows: Since Last Lesson card · Trend dots · Needs Work · Lesson Stats · Recent Sessions
- [ ] Daniel's Repertoire tab shows: Bach Minuet with star ratings + notes
- [ ] Welcome card disappears after onboarding
- [ ] Re-opening dashboard does NOT show welcome card

## 4. Lesson recording (Teacher Edition)

- [ ] Pick Sarah as active student via the chip
- [ ] Home menu shows "Today's Assignments" card with 2 open assignments
- [ ] Home menu shows "Recommended Next" card (since Sarah has weak items)
- [ ] Tap "▶ Start Lesson" — button changes to "■ End Lesson" with elapsed timer
- [ ] Navigate to a mode (e.g. Interval) → button collapses to small chip top-right
- [ ] Start the quiz → chip HIDES during active question
- [ ] Answer a few questions, finish → chip reappears on result screen
- [ ] Tap "■ End Lesson" or the chip → end-of-lesson modal appears
- [ ] Modal shows: headline scaled to accuracy, Time / Rounds / Accuracy / Correct chips, activity list
- [ ] "Send Parent Summary" saves HTML, second dialog opens with "Open in browser" button
- [ ] Browser opens the parent summary; content includes headline, trend bars, focus areas, plan
- [ ] "Save Lesson Note" persists to lesson_log; modal closes
- [ ] Sarah's dashboard Overview shows the new lesson entry

## 5. Assignment bridge (Teacher Edition)

- [ ] After a session, "Mark Assignment Done" button appears on the result screen
- [ ] Tapping it opens a checkbox picker
- [ ] Marking + confirming updates the dashboard's open count
- [ ] Returning to home — the "Today's Assignments" card updates (or hides if all done)

## 6. Cloud sync (Teacher Edition)

- [ ] Home menu shows sync pill: "Cloud Sync: not signed in"
- [ ] Open dashboard → Cloud Sync button at top
- [ ] Sign in with email + magic-link OTP (or skip if no test account)
- [ ] After sign-in, home pill updates to "Synced X min ago"
- [ ] Push a snapshot → success message
- [ ] On another device (or after deleting local data + restoring), pull the snapshot
- [ ] Confirm `user://sync_backups/` contains a `pre_restore_*.json` from the pull

## 7. Settings + About

- [ ] Open Settings from home (gear icon)
- [ ] Diagnostics card shows: Build / Sync / MIDI status / Support link
- [ ] "Terms (EULA)" button opens EULA in browser
- [ ] "Privacy Policy" button opens Privacy in browser
- [ ] "Credits" button opens LICENSES.md
- [ ] "Logs Folder" button opens the `logs/` folder in Explorer (auto-creates if missing)
- [ ] Settings gear icon is **hidden** in the gameplay header (only visible on home overview)

## 8. Quit-during-lesson protection

- [ ] Start a lesson with the active student
- [ ] Click the window's X (close button)
- [ ] Branded dialog appears: "End the lesson before quitting?"
- [ ] "End & Save" runs the end-of-lesson flow then quits
- [ ] On next launch, the lesson was saved (visible in dashboard)
- [ ] Re-test: pick "Discard & Quit" → app closes without saving the lesson
- [ ] Re-test: pick "Keep Lesson Open" → app stays open, lesson still active

## 9. Crash log writer

- [ ] After a clean exit, `user://logs/` contains a `session_<ts>.log` (the previous session)
- [ ] The log includes: started_at, app_version, godot version, OS, edition, user_data_dir, ended_at, CLEAN_EXIT
- [ ] To test crash detection: kill the .exe via Task Manager mid-session
- [ ] Re-launch: previous log should be rotated to `crash_<ts>.log` (no CLEAN_EXIT line)

## 10. Responsive layout

- [ ] Drag the window to a narrow width (e.g., 500 px wide)
- [ ] The grand staff in Sight Chords resizes to fit (no horizontal scrollbar, no clipping)
- [ ] Sight Notes setup row fits without horizontal overflow

## 11. Visual polish

- [ ] All dialogs (assignment picker, summary saved, parent summary, lesson log delete) wear the dark-navy/teal branded look
- [ ] End-of-lesson modal bounces in
- [ ] Active student chip hides during active quiz
- [ ] Disabled buttons (e.g., disabled Replay) still look like buttons, not plain text
- [ ] Chord tier headers (Triads / 7ths / 6ths / Extensions) look like section dividers, not unstyled wide bars
- [ ] Note Chase fail/spawn lines have companion labels ("🎯 tap here" / "notes ←")

## 12. Data migration (only if testing on a machine with legacy data)

- [ ] Put a `teacher_data.json` in `%APPDATA%\Godot\app_userdata\MusicEd - Interval Birds\`
- [ ] Delete `%APPDATA%\Godot\app_userdata\Clefira\` (so it's empty)
- [ ] Launch Clefira
- [ ] Check console / `session.log` — should mention `[Migration] Copied N legacy files`
- [ ] Verify `app_userdata/Clefira/` now has the legacy teacher_data.json
- [ ] Open dashboard — old students should appear

---

## Sign-off

- Tester: ____________________
- Date: ______________________
- Build: `v1.0.0` (or whatever you bumped to)
- Edition: ☐ Teacher  ☐ Student
- Verdict: ☐ PASS — ready to ship  ☐ FAIL — see notes
- Blocker notes:

```
(notes here)
```
