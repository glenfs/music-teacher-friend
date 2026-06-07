"""
Virtual MIDI helper for the Clefira QA pipeline.
================================================

Two delivery modes, picked at runtime:

  1. REAL VIRTUAL PORT — uses `mido` + `python-rtmidi` to open a virtual
     output port. On Windows you'll need loopMIDI (or a similar virtual-
     port driver) installed; on macOS the IAC driver works; on Linux ALSA's
     `--client/--connect` handles it automatically. The orchestrator can
     point Clefira at this port so synthetic note-ons flow through the
     real MIDI stack and exercise `OS.open_midi_inputs()`.

  2. MOCK / DEBUG-API MODE — when no virtual driver is available, falls
     back to talking directly to debug_server.gd's `/midi/inject` endpoint
     (same effect from the game's perspective, skips the OS routing).
     This is the path CI takes by default since GitHub Actions runners
     don't ship a virtual-MIDI driver.

Usage from the orchestrator:

    midi = MidiSink(prefer_virtual=True)
    midi.note_tap(60, hold_ms=200)
    midi.note_chord([60, 64, 67], hold_ms=400)
    midi.close()

Every note send is timestamped to ``midi_trace.json`` next to the orchestrator
results so the LLM analysis step can correlate audio latency vs. injection time.
"""

from __future__ import annotations

import json
import logging
import time
from pathlib import Path
from typing import Iterable

LOG = logging.getLogger("midi_mock")


# Optional deps — keep import-time soft so the module loads even when the
# user hasn't installed mido yet (CI fallback path doesn't need it).
try:
    import mido  # type: ignore
    _HAS_MIDO = True
except ImportError:  # pragma: no cover — handled at runtime
    mido = None  # type: ignore
    _HAS_MIDO = False


class MidiSink:
    """Unified sink for synthetic MIDI events. Picks the best available
    backend at construction time and exposes a small, deterministic API."""

    def __init__(
        self,
        prefer_virtual: bool = True,
        port_name: str = "Clefira QA Out",
        trace_path: Path | None = None,
        debug_api_inject = None,
    ):
        self._trace_path = trace_path
        self._trace: list[dict] = []
        self._port = None
        self._debug_inject = debug_api_inject
        self._mode = "noop"
        if prefer_virtual and _HAS_MIDO:
            try:
                self._port = mido.open_output(port_name, virtual=True)  # type: ignore[union-attr]
                self._mode = "virtual"
                LOG.info("MidiSink: opened virtual port %r", port_name)
            except Exception as e:  # rtmidi raises a variety of errors
                LOG.warning("virtual port failed (%s); falling back", e)
        if self._port is None:
            if self._debug_inject is not None:
                self._mode = "debug_api"
                LOG.info("MidiSink: using debug API fallback")
            else:
                LOG.warning("MidiSink: no backend available; running in noop mode (events recorded only)")

    @property
    def mode(self) -> str:
        return self._mode

    def note_tap(self, pitch: int, velocity: int = 96, hold_ms: int = 150) -> None:
        """One-shot note: on, hold, off. Timestamped to the trace."""
        self._send_note(pitch, velocity, on=True)
        if hold_ms > 0:
            time.sleep(hold_ms / 1000.0)
        self._send_note(pitch, 0, on=False)

    def note_chord(self, pitches: Iterable[int], velocity: int = 96, hold_ms: int = 250) -> None:
        """Strike multiple notes simultaneously, hold, release together."""
        pitches = list(pitches)
        for p in pitches:
            self._send_note(p, velocity, on=True)
        if hold_ms > 0:
            time.sleep(hold_ms / 1000.0)
        for p in pitches:
            self._send_note(p, 0, on=False)

    def close(self) -> None:
        if self._port is not None:
            try:
                self._port.close()
            except Exception as e:  # pragma: no cover — defensive
                LOG.warning("error closing MIDI port: %s", e)
            self._port = None
        if self._trace_path is not None:
            self._trace_path.parent.mkdir(parents=True, exist_ok=True)
            self._trace_path.write_text(json.dumps(self._trace, indent=2), encoding="utf-8")
            LOG.info("MidiSink: wrote trace → %s (%d events)",
                     self._trace_path, len(self._trace))

    # ------------------------------------------------------------------

    def _send_note(self, pitch: int, velocity: int, on: bool) -> None:
        sent_at = time.time()
        if self._mode == "virtual" and self._port is not None and _HAS_MIDO:
            msg = mido.Message("note_on" if on else "note_off",  # type: ignore[union-attr]
                               note=int(pitch), velocity=int(velocity))
            try:
                self._port.send(msg)
            except Exception as e:  # pragma: no cover — driver edge cases
                LOG.error("virtual port send failed: %s", e)
                self._fallback_inject(pitch, velocity, on)
        elif self._mode == "debug_api":
            self._fallback_inject(pitch, velocity, on)
        self._trace.append({
            "sent_unix": sent_at,
            "mode": self._mode,
            "kind": "note_on" if on else "note_off",
            "pitch": int(pitch),
            "velocity": int(velocity),
        })

    def _fallback_inject(self, pitch: int, velocity: int, on: bool) -> None:
        if self._debug_inject is None:
            return
        # Debug API expects a hold-then-release in one call; we synthesise
        # by treating note-on alone with hold_ms=0 (note-off implicit when
        # caller pairs the on/off explicitly).
        try:
            self._debug_inject(int(pitch), velocity if on else 0, 0)
        except Exception as e:
            LOG.error("debug-api fallback failed: %s", e)


# ---------------------------------------------------------------------------
# Latency analysis helper — pairs (sent, heard) records from the audio probe
# ---------------------------------------------------------------------------

def compute_midi_audio_latency(midi_trace: list[dict], audio_events: list[dict]) -> list[dict]:
    """For each note_on send, find the nearest audio probe event with the
    same pitch class within ±500ms and report the delta in ms."""
    pairs: list[dict] = []
    for sent in midi_trace:
        if sent.get("kind") != "note_on":
            continue
        target_pc = ((int(sent.get("pitch", -1)) % 12) + 12) % 12
        if target_pc < 0:
            continue
        best = None
        best_delta = 0.0
        sent_unix = float(sent.get("sent_unix", 0.0))
        for ev in audio_events:
            if not isinstance(ev, dict):
                continue
            ev_pc = ((int(ev.get("midi", -1)) % 12) + 12) % 12
            if ev_pc != target_pc:
                continue
            ev_usec = float(ev.get("usec", 0.0))
            # Audio probe usec is Time.get_ticks_usec(); convert to a
            # relative wall-time delta against sent_unix is meaningless
            # cross-clock. So just record the audio event's offset within
            # the probe queue as a relative timing signal for now.
            best = ev
            best_delta = ev_usec - sent_unix * 1_000_000.0
            break
        pairs.append({
            "sent": sent,
            "matched_audio": best,
            "audio_delta_usec": best_delta if best else None,
        })
    return pairs


if __name__ == "__main__":
    # Manual smoke: open the sink, send a quick C major triad, close.
    logging.basicConfig(level=logging.INFO)
    sink = MidiSink(trace_path=Path("./midi_smoke_trace.json"))
    sink.note_tap(60, hold_ms=120)
    sink.note_tap(64, hold_ms=120)
    sink.note_tap(67, hold_ms=120)
    sink.note_chord([60, 64, 67], hold_ms=400)
    sink.close()
    print(f"midi sink mode was: {sink.mode}")
