# Clefira AI-Orchestrated QA Pipeline — Setup & Run

This pipeline drives a built **Clefira.exe** via an in-game HTTP debug API,
runs YAML test cases, optionally injects MIDI (virtual or via the debug
API), and emits JSON results an LLM can triage. It complements the
existing in-engine QA harness (`qa_run.ps1` + `scripts/qa/qa_runner.gd`)
— that one runs scripted scenarios from inside the engine, this one
drives the running game from outside.

## Architecture

```
┌─────────────────────────────────┐
│  Python Orchestrator (host OS)  │
│  - test_cases.yaml              │
│  - qa_orchestrator.py           │
│  - midi_mock_setup.py           │
└──────────────┬──────────────────┘
               │ HTTP /JSON  (127.0.0.1:8765)
               ▼
┌─────────────────────────────────┐    Virtual or       ┌──────────────────┐
│  Clefira.exe (Godot 4.6)        │    debug-API MIDI   │  loopMIDI / IAC  │
│  scripts/qa/debug_server.gd     │◄───────────────────►│  (optional)      │
└─────────────────────────────────┘                     └──────────────────┘
               │ qa_results.json + qa_logs.json + screenshots
               ▼
┌─────────────────────────────────┐
│  LLM Analysis Step              │
│  - llm_qa_analysis_prompt.md    │
│  → Claude / GPT triage report   │
└─────────────────────────────────┘
```

## 1. Python dependencies

Python 3.10+ required.

```bash
cd qa/orchestrator
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

`mido` + `python-rtmidi` are optional — they let `midi_mock_setup.py` open
a real virtual MIDI port. Without them the script falls back to injecting
notes via the debug server's `/midi/inject` endpoint, which is equivalent
from the game's perspective.

## 2. Virtual MIDI driver (optional)

Skip this section if you're happy with the debug-API fallback (the
default in CI).

- **Windows**: install **[loopMIDI](https://www.tobias-erichsen.de/software/loopmidi.html)**.
  Open loopMIDI, click `+` to add a port named `Clefira QA Out` (matching
  `port_name` in `MidiSink.__init__`). Then in Clefira's Settings dialog
  make sure MIDI input is enabled.
- **macOS**: open **Audio MIDI Setup → MIDI Studio → IAC Driver**, tick
  "Device is online", add a port called `Clefira QA Out`.
- **Linux**: ALSA virtual ports work out of the box; nothing to install.

## 3. Build Clefira with debug-server support

The debug server lives in `scripts/qa/debug_server.gd` and bootstraps
when the binary is launched with `--debug-server [port]`. No special
export preset is needed — the script ships in every build. Export your
Windows release as normal:

```
File → Export → Windows Desktop → Export Project → build/Clefira.exe
```

To smoke-test locally without an export, you can run the editor headlessly:

```powershell
$env:GODOT_BIN = "C:\Path\To\Godot_v4.6-stable_win64.exe"
& $env:GODOT_BIN --headless --path . -- --debug-server 8765
```

Then in another terminal:

```bash
curl http://127.0.0.1:8765/health
# {"ok": true, "build": "Clefira/...", "mode": -1, ...}
```

## 4. Run the orchestrator

### Auto-launch mode (typical CI usage)

```bash
python qa_orchestrator.py --build ../../build/Clefira.exe --verbose
```

This:
1. Launches `Clefira.exe --headless -- --debug-server 8765`
2. Polls `/health` until ready (or 30s timeout)
3. Runs every case in `test_cases.yaml`
4. Writes `results/qa_results.json`, `results/qa_logs.json`, and any
   screenshots under `results/screenshots/`
5. Sends `/quit` so Clefira shuts down cleanly
6. Exits 0 on pass, 1 on failure(s), 2 on config error, 3 on
   unreachable debug server

### Filtered run

```bash
python qa_orchestrator.py --build ../../build/Clefira.exe --tag smoke
python qa_orchestrator.py --build ../../build/Clefira.exe --name "Mode transition matrix"
```

### Attach to a manually-launched game

If you're debugging interactively and Clefira is already running with
`--debug-server`:

```bash
python qa_orchestrator.py --no-launch --port 8765
```

### Customisation points

- **Add a new test case**: append to `test_cases.yaml`. Action names map
  one-to-one to methods on `DebugClient` (`qa_orchestrator.py:DebugClient`).
- **Add a new endpoint**: extend `scripts/qa/debug_server.gd`'s
  `_dispatch` match. Mirror it as a method on `DebugClient`.
- **Tighten assertions**: use the `assert` action with `op: gte` /
  `lte` / `in` rather than wrapping in Python — the JSON output is
  cleaner when the assertion lives in the YAML.

## 5. LLM analysis

After the run:

```bash
cat llm_qa_analysis_prompt.md \
    results/qa_results.json \
    results/qa_logs.json \
    > /tmp/llm_input.md
```

Paste into Claude (Sonnet 4.6+) or GPT-4. The prompt forces a structured
triage report distinguishing regressions, state bugs, MIDI drift, and
flaky tests.

To automate the analysis as well, the Claude / OpenAI APIs both accept
this same prompt + the JSON file contents.

## 6. GitHub Actions integration

A workflow that runs both the existing in-engine harness AND this new
orchestrator lives at `.github/workflows/qa.yml`. The orchestrator job
depends on the existing engine cache so cold-start cost is minimal:

```yaml
  qa_orchestrator:
    needs: qa
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - name: Install orchestrator deps
        run: pip install -r qa/orchestrator/requirements.txt
      # Build step assumed to publish build/Clefira.exe before this point.
      - name: Run orchestrator
        run: python qa/orchestrator/qa_orchestrator.py --build build/Clefira.exe --verbose
      - uses: actions/upload-artifact@v4
        with:
          name: qa-orchestrator-${{ github.run_id }}
          path: qa/orchestrator/results/**
```

Failures bubble up via the exit code, so a red orchestrator run blocks
the PR like any other check.

## 7. Three-step validation checklist

After installing, run these in order. All three should pass before
trusting CI integration:

1. **Debug server reachable**
   ```bash
   curl http://127.0.0.1:8765/health
   ```
   Expect HTTP 200 with `{"ok": true, ...}`. Confirms the export
   includes `debug_server.gd` and the `--debug-server` flag wired in.

2. **Orchestrator runs the smoke tag clean**
   ```bash
   cd qa/orchestrator
   python qa_orchestrator.py --build ../../build/Clefira.exe --tag smoke --verbose
   ```
   Expect exit 0 and `results/qa_results.json` showing
   `summary.passed > 0, failed == 0`. Confirms the dispatch table works
   end-to-end.

3. **MIDI smoke**
   ```bash
   python midi_mock_setup.py
   ```
   Expect a single line `midi sink mode was: virtual` (or `debug_api`
   fallback) plus `./midi_smoke_trace.json` written with 7 events
   (4 single notes + a 3-note chord). Confirms either the virtual MIDI
   driver or the debug-API fallback path is wired.

If any step fails, check `setup_and_run.md` against your environment and
re-run with `--verbose` to see the failing HTTP call.
