# Release SKU Strategy

Planning note for when Clefira is closer to release.

## Product Split

We plan to ship two related SKUs from the same product system:

1. **Clefira Teacher**
   - Paid app/SKU.
   - Includes teacher dashboard, student roster, exercise generation, lesson tools, assignments, reports, and progress review.
   - Main customer is the teacher/studio.

2. **Clefira Student**
   - Free app/SKU.
   - Targeted at students age 13+ and adult learners.
   - Includes practice games, sight reading, note/chord exercises, assigned drills, and local progress.
   - Should be useful without a teacher, but more valuable when connected to a teacher.

## Positioning

Teacher:
- "Studio/classroom toolkit for assigning and tracking music practice."
- Paid because it creates, manages, and analyzes student work.

Student:
- "Free practice companion for teens and adult learners."
- Avoid positioning as a child-directed app.
- Keep branding mature enough for high school, college beginners, adult learners, and private music students.

## Architecture Direction

Prefer one shared Godot project with separate export presets and feature flags:

- Shared core:
  - Audio engine
  - Piano samples
  - Score renderer
  - Sight reading games
  - Note/chord/interval logic
  - Branding system

- Teacher-only:
  - Teacher dashboard
  - Student roster
  - Assignment builder
  - Exercise generator controls
  - Reports/export
  - Studio analytics

- Student-only:
  - Simple home flow
  - Today/practice queue
  - Assigned exercises
  - Free practice games
  - Teacher code pairing

This avoids maintaining two divergent codebases.

## 13+ Student Policy Direction

For the Student SKU:

- Target age 13+.
- Do not market it as a kids-under-13 app.
- Avoid ads and third-party tracking in v1.
- Avoid collecting birthdays unless an age gate becomes necessary.
- Prefer nickname/local profile/teacher code over email login at launch.
- Do not require real names for student accounts.
- Keep teacher rosters minimal and privacy-conscious.
- Prepare a plain privacy policy and data deletion path before release.

## Monetization Notes

Preferred v1:

- Student app: free.
- Teacher app: paid.

Possible future models:

- Teacher free trial with paid Pro unlock.
- Teacher subscription if cloud sync, multi-device roster sync, or hosted assignment delivery becomes core.
- Desktop/tablet teacher license plus free mobile student app.

Important platform consideration:

- If paid digital features are unlocked inside iOS/Android apps, platform billing rules may require Apple/Google in-app purchase.
- A simple paid Teacher SKU may be easier than building account/subscription infrastructure for v1.

## Release Checklist Before SKU Split

- Decide app IDs/package names for Teacher and Student.
- Add separate export presets and icons.
- Add feature flags for teacher-only and student-only modules.
- Confirm Student home screen has no teacher dashboard access.
- Confirm Teacher app includes the full student/assignment workflow.
- Verify project settings, title bar icon, splash, and export icons per SKU.
- Write app store descriptions with clear audience:
  - Teacher: paid teacher/studio tool.
  - Student: free 13+ practice companion.
- Write privacy policy.
- Decide whether any cloud sync exists in v1.
- Test a clean first-run flow for both SKUs.
