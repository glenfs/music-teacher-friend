from __future__ import annotations

import ctypes
import json
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

import requests
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "builds" / "windows" / "student" / "ClefiraStudent.exe"
OUT_DIR = ROOT / "website" / "assets" / "videos"
FRAME_DIR = ROOT / "build" / "student_demo_frames"
OUT_MP4 = OUT_DIR / "clefira-student-demo.mp4"
PORT = 8765
FPS = 12
TARGET_SIZE = (1920, 1080)

REF_W = 1296.0
REF_H = 759.0


user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32


class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", ctypes.c_ulong),
        ("biWidth", ctypes.c_long),
        ("biHeight", ctypes.c_long),
        ("biPlanes", ctypes.c_ushort),
        ("biBitCount", ctypes.c_ushort),
        ("biCompression", ctypes.c_ulong),
        ("biSizeImage", ctypes.c_ulong),
        ("biXPelsPerMeter", ctypes.c_long),
        ("biYPelsPerMeter", ctypes.c_long),
        ("biClrUsed", ctypes.c_ulong),
        ("biClrImportant", ctypes.c_ulong),
    ]


class BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", ctypes.c_ulong * 3)]


def request(method: str, path: str, **kwargs: Any) -> dict[str, Any]:
    url = f"http://127.0.0.1:{PORT}{path}"
    response = requests.request(method, url, timeout=5, **kwargs)
    response.raise_for_status()
    return response.json()


def wait_for_server(timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            if request("GET", "/health").get("ok"):
                return
        except Exception as exc:
            last_error = exc
        time.sleep(0.4)
    raise RuntimeError(f"debug server did not start: {last_error}")


def get_member(member: str) -> Any:
    data = request(
        "POST",
        "/assert",
        json={"member": member, "op": "ne", "value": "__codex_demo_sentinel__"},
    )
    return data.get("observed")


def get_state() -> dict[str, Any]:
    return request("GET", "/state")


def switch_mode(mode: int) -> None:
    request("POST", "/mode", json={"mode": mode})


def find_window() -> int:
    hwnd = user32.FindWindowW(None, "Clefira")
    if not hwnd:
        raise RuntimeError("Clefira window not found")
    return hwnd


def restore_window(hwnd: int) -> tuple[int, int]:
    user32.ShowWindow(hwnd, 9)  # SW_RESTORE
    user32.SetWindowPos(hwnd, -1, 80, 80, 1296, 759, 0x0040)  # HWND_TOPMOST, SWP_SHOWWINDOW
    rect = RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    if rect.left <= -30000:
        raise RuntimeError("Clefira window is still minimized")
    return rect.right - rect.left, rect.bottom - rect.top


def click_ref(hwnd: int, x_ref: float, y_ref: float) -> None:
    w, h = restore_window(hwnd)
    x = int(round(x_ref * (w / REF_W)))
    y = int(round(y_ref * (h / REF_H)))
    lparam = (y << 16) | (x & 0xFFFF)
    user32.PostMessageW(hwnd, 0x0201, 1, lparam)  # WM_LBUTTONDOWN
    time.sleep(0.08)
    user32.PostMessageW(hwnd, 0x0202, 0, lparam)  # WM_LBUTTONUP


def click_until(hwnd: int, coords: list[tuple[float, float]], predicate, timeout: float = 5.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        for coord in coords:
            click_ref(hwnd, *coord)
            time.sleep(0.35)
            if predicate():
                return
    raise RuntimeError("click target did not produce the expected state change")


def capture_window(hwnd: int) -> Image.Image:
    w, h = restore_window(hwnd)
    hdc = user32.GetWindowDC(hwnd)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mem, bmp)
    ok = user32.PrintWindow(hwnd, mem, 3)
    if not ok:
        raise RuntimeError("PrintWindow failed")

    bi = BITMAPINFO()
    bi.bmiHeader.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bi.bmiHeader.biWidth = w
    bi.bmiHeader.biHeight = -h
    bi.bmiHeader.biPlanes = 1
    bi.bmiHeader.biBitCount = 32
    bi.bmiHeader.biCompression = 0
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bi), 0)
    img = Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1).copy()

    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(hwnd, hdc)
    return img


def fit_16x9(img: Image.Image) -> Image.Image:
    target_ratio = TARGET_SIZE[0] / TARGET_SIZE[1]
    src_ratio = img.width / img.height
    if src_ratio > target_ratio:
        new_w = int(round(img.height * target_ratio))
        left = (img.width - new_w) // 2
        img = img.crop((left, 0, left + new_w, img.height))
    else:
        new_h = int(round(img.width / target_ratio))
        top = max(0, (img.height - new_h) // 2)
        img = img.crop((0, top, img.width, top + new_h))
    return img.resize(TARGET_SIZE, Image.Resampling.LANCZOS).convert("RGB")


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        ROOT / "assets" / "fonts" / "Inter-Medium.ttf",
        ROOT / "assets" / "fonts" / "Inter-Light.ttf",
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


CAPTION_FONT = load_font(38)
SMALL_FONT = load_font(24)


def add_caption(img: Image.Image, caption: str | None) -> Image.Image:
    if not caption:
        return img
    draw = ImageDraw.Draw(img, "RGBA")
    margin = 48
    max_width = TARGET_SIZE[0] - margin * 2
    words = caption.split()
    lines: list[str] = []
    current = ""
    for word in words:
        test = word if not current else f"{current} {word}"
        if draw.textbbox((0, 0), test, font=CAPTION_FONT)[2] <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    lines = lines[:2]
    line_h = 48
    box_h = line_h * len(lines) + 44
    y0 = TARGET_SIZE[1] - box_h - 34
    draw.rounded_rectangle((34, y0, TARGET_SIZE[0] - 34, y0 + box_h), radius=14, fill=(7, 20, 32, 176))
    for i, line in enumerate(lines):
        draw.text((margin, y0 + 22 + i * line_h), line, font=CAPTION_FONT, fill=(246, 248, 250, 255))
    return img


class Recorder:
    def __init__(self, hwnd: int):
        self.hwnd = hwnd
        self.frame = 0

    def grab(self, caption: str | None = None) -> None:
        img = add_caption(fit_16x9(capture_window(self.hwnd)), caption)
        img.save(FRAME_DIR / f"frame_{self.frame:05d}.jpg", quality=92, subsampling=1)
        self.frame += 1

    def hold(self, seconds: float, caption: str | None = None) -> None:
        frames = max(1, int(round(seconds * FPS)))
        for _ in range(frames):
            self.grab(caption)
            time.sleep(1.0 / FPS)


def wait_until(predicate, timeout: float = 8.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(0.2)
    return False


def answer_sight_question(hwnd: int) -> None:
    answer = str(get_member("_current_sight_note") or "").strip()
    key = answer if answer in SIGHT_NOTE_COORDS else answer[:1]
    coords = SIGHT_NOTE_COORDS.get(key)
    if coords:
        click_ref(hwnd, *coords)


def answer_ear_question(hwnd: int) -> None:
    answer = get_member("_current_ear_text_answer")
    choices = get_member("_current_ear_text_choices")
    if not isinstance(choices, list) or answer not in choices:
        return
    idx = choices.index(answer)
    coords = EAR_CHOICE_COORDS[min(idx, len(EAR_CHOICE_COORDS) - 1)]
    click_ref(hwnd, *coords)


SIGHT_NOTE_COORDS = {
    "C": (1015, 263),
    "D": (1090, 263),
    "E": (1015, 306),
    "F": (1090, 306),
    "G": (1015, 350),
    "A": (1090, 350),
    "B": (1015, 394),
}

EAR_CHOICE_COORDS = [(450, 607), (835, 607), (450, 665), (835, 665)]


def render_video() -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found on PATH")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        ffmpeg,
        "-y",
        "-r",
        str(FPS),
        "-i",
        str(FRAME_DIR / "frame_%05d.jpg"),
        "-vcodec",
        "libx264",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-an",
        str(OUT_MP4),
    ]
    subprocess.run(cmd, check=True)


def main() -> None:
    if not EXE.exists():
        raise FileNotFoundError(EXE)

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for old_frame in FRAME_DIR.glob("frame_*.jpg"):
        old_frame.unlink()

    subprocess.run(
        ["powershell", "-NoProfile", "-Command", "Get-Process ClefiraStudent -ErrorAction SilentlyContinue | Stop-Process -Force"],
        cwd=ROOT,
        check=False,
    )

    proc = subprocess.Popen(
        [str(EXE), "--windowed", "--resolution", "1366x768", "--", "--debug-server", str(PORT)],
        cwd=EXE.parent,
    )
    try:
        wait_for_server()
        time.sleep(5.0)
        hwnd = find_window()
        restore_window(hwnd)
        recorder = Recorder(hwnd)

        recorder.hold(3.0, "Student home: focused practice, clear progress, and quick tools.")

        switch_mode(2)
        time.sleep(1.0)
        recorder.hold(2.5, "Sight Reading setup: notes, recall, interval reading, chords, mic and MIDI options.")

        click_until(
            hwnd,
            [(400, 695), (405, 680), (380, 690), (430, 690), (390, 660)],
            lambda: bool(get_state().get("quiz_active")),
            6.0,
        )
        recorder.hold(1.0, "Start a short sight-reading round.")
        click_until(
            hwnd,
            [(683, 384), (685, 405), (675, 365), (645, 385)],
            lambda: bool(get_member("_accepting_answer")),
            8.0,
        )
        recorder.hold(2.0, "Read the staff and choose the matching note.")
        for i in range(2):
            answer_sight_question(hwnd)
            recorder.hold(1.6, "Instant feedback updates accuracy, score, and streak.")
            wait_until(lambda: bool(get_member("_accepting_answer")) or not bool(get_state().get("quiz_active")), 5.0)

        click_ref(hwnd, 1225, 38)
        time.sleep(1.0)

        switch_mode(0)
        time.sleep(1.0)
        recorder.hold(2.5, "Ear Training setup: intervals, chords, pitch match, and cadences.")
        click_until(
            hwnd,
            [(500, 695), (485, 680), (450, 690), (520, 690), (500, 660)],
            lambda: bool(get_state().get("quiz_active")),
            6.0,
        )
        recorder.hold(1.2, "Listen to the prompt, then start the round.")
        click_until(
            hwnd,
            [(638, 305), (625, 305), (650, 305), (638, 325)],
            lambda: bool(get_member("_accepting_answer")),
            8.0,
        )
        recorder.hold(2.0, "Choose the interval you hear.")
        answer_ear_question(hwnd)
        recorder.hold(2.0, "Correct-answer feedback keeps the loop quick.")

        click_ref(hwnd, 1225, 38)
        time.sleep(1.0)
        recorder.hold(2.5, "Current student edition also surfaces Functional Ear Training and Chord Explorer from the home screen.")

        click_ref(hwnd, 1228, 42)
        time.sleep(1.0)
        recorder.hold(2.0, "Student settings keep tempo, choice count, sound, profile, and diagnostics close at hand.")
        click_ref(hwnd, 640, 695)
        time.sleep(0.8)
        recorder.hold(1.5, "Clefira Student Edition v1.0.0")

        render_video()
        print(json.dumps({"video": str(OUT_MP4), "frames": recorder.frame}, indent=2))
    finally:
        try:
            request("POST", "/quit")
        except Exception:
            pass
        try:
            proc.wait(timeout=4)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
