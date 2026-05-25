# Clefira Desktop Release — Step-by-Step Process

Use this every time you cut a new desktop release. Skip steps that don't apply (e.g., signing if you haven't bought a cert yet).

---

## Phase 1 — Pre-release housekeeping

### 1.1 Bump version
- [ ] Edit `scripts/interval_birds.gd`: `APP_VERSION_LABEL` → new version (e.g., `"v1.0.1"`)
- [ ] If this release introduces breaking terms changes: bump `TERMS_CURRENT_VERSION` in `scripts/interval_birds.gd` so existing users re-accept

### 1.2 Resolve LICENSES.md (hard blocker for paid release)
- [ ] Open `LICENSES.md` — every entry tagged `TBD` must be resolved before public sale
- [ ] For each TBD: write actual source URL + license + author + attribution requirement
- [ ] For each `Verify` / `Confirm` entry: cross-check the deduced source and confirm/correct
- [ ] If any asset can't be traced, **replace it** before release

### 1.3 Update EULA + Privacy placeholders
- [ ] Open `docs/EULA.html` — replace `[Your Legal Name / Company]`, `[Your Jurisdiction]`, and `[your-support-email@example.com]`
- [ ] Open `docs/PRIVACY.html` — same support email placeholder
- [ ] Confirm cloud-sync provider name matches what's actually used (default: Supabase)

### 1.4 Run QA
```powershell
.\qa_run.ps1
```
- [ ] Output ends with `QA DONE PASS`
- [ ] Note any new warnings (existing benign ones: 6 CanvasItems / 2 FontAdvanced / 1 resource / DummyTextures — all pre-existing headless artifacts)

### 1.5 Manual smoke test
- [ ] Run through every item in `docs/release_smoke_test.md`
- [ ] Test on a clean Windows machine (or with renamed userdata dir)

---

## Phase 2 — Build

### 2.1 Open Godot editor
```powershell
& "C:\ProgrammingLanguages\gadot\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe" --path .
```

### 2.2 Export Windows builds
- [ ] **Project → Export…**
- [ ] Select **Windows Desktop - Teacher** → Export Project → `builds/windows/teacher/ClefiraTeacher.exe`
- [ ] Select **Windows Desktop - Student** → Export Project → `builds/windows/student/ClefiraStudent.exe`
- [ ] Verify each export folder contains:
  - `Clefira(Teacher|Student).exe`
  - `Clefira(Teacher|Student).pck`
  - No `docs/`, no `qa/`, no `.md` files (export filter excludes these)
  - EULA.html and PRIVACY.html should be inside the .pck (auto-extracted on first browser-open by `_open_local_doc`)

### 2.3 Verify the exe runs on the build machine
- [ ] Double-click the exe — splash plays, terms modal appears (assuming fresh userdata)
- [ ] Walk through 30 seconds of normal play

---

## Phase 3 — Sign (optional but recommended)

Without signing, Windows SmartScreen will warn "Unknown publisher". Many users will close the warning and abandon the install.

### 3.1 Buy a code-signing certificate
- [ ] Sectigo / DigiCert / SSL.com — Standard CS cert ~$200/yr, EV CS cert ~$400/yr (instant SmartScreen reputation)
- [ ] OV certs take ~3-7 days to issue; EV requires hardware token

### 3.2 Sign the executable
Using Microsoft `signtool` (ships with the Windows SDK):
```powershell
signtool sign /a /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "builds\windows\teacher\ClefiraTeacher.exe"
signtool sign /a /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "builds\windows\student\ClefiraStudent.exe"
```
- [ ] Verify: right-click exe → Properties → Digital Signatures tab shows your cert

---

## Phase 4 — Package

### 4.1 Zip for distribution
```powershell
Compress-Archive -Path "builds\windows\teacher\*" -DestinationPath "builds\Clefira-Teacher-v1.0.0-Windows.zip"
Compress-Archive -Path "builds\windows\student\*" -DestinationPath "builds\Clefira-Student-v1.0.0-Windows.zip"
```

### 4.2 Optional: Build an installer
For a more pro feel, use **Inno Setup** (free) or **NSIS**:
- [ ] Create a `.iss` script that bundles the .exe + .pck + a Start Menu shortcut
- [ ] Output: `Clefira-Teacher-v1.0.0-Setup.exe`
- [ ] Sign the installer too (same signtool command)

---

## Phase 5 — Distribute

### 5.1 itch.io (recommended for beta + first release)
- [ ] Create account at https://itch.io/dashboard → New project
- [ ] Title: Clefira
- [ ] Genre: Educational
- [ ] Upload the `.zip` (or installer)
- [ ] Set price: Free / pay-what-you-want / fixed
- [ ] Pricing tip for beta: "Pay what you want" with $0 minimum + $5 suggested
- [ ] Add screenshots (5-8), short description, long description (the in-app About content)
- [ ] Tags: `music`, `educational`, `piano`, `teacher`, `ear-training`
- [ ] Publish

### 5.2 Steam (later, when paid + signed)
- [ ] Steamworks account ($100 one-time per app)
- [ ] App page, build upload via SteamPipe, Steam Direct review (~2 weeks)
- [ ] Requires age-rating questionnaire (IARC)

### 5.3 Direct sale (own site)
- [ ] Stripe / Paddle / Gumroad for payment
- [ ] Download link gated by license key
- [ ] You handle hosting, support, refunds

---

## Phase 6 — Post-release

### 6.1 Announce
- [ ] Personal email to beta teachers
- [ ] Post to r/pianoteachers, r/musictheory
- [ ] Twitter/X with a 30-second demo video
- [ ] LinkedIn for piano-teacher network

### 6.2 Monitor
- [ ] Set up email forwarding for the support address
- [ ] Watch itch.io comments daily for the first week
- [ ] Ask beta users to forward `user://logs/crash_*.log` if anything blows up

### 6.3 Hotfix pipeline
- [ ] Keep the source tree on a `release-1.0.x` branch
- [ ] Bump version, re-run smoke test, re-export, re-sign, re-zip, re-upload
- [ ] itch.io's "Update game" button replaces the existing download

---

## Known limitations to note in release announcement

- Cloud sync requires Supabase keys configured in `scripts/sync/sync_config.gd` — empty out of the box
- MIDI tested on Windows; Mac/Linux untested
- Sight Singing module is in beta (gated via `_sight_mode == "Sight Singing"`)
- No auto-update — users download new versions manually from itch.io
- No telemetry — bug reports come via the user emailing a crash log
