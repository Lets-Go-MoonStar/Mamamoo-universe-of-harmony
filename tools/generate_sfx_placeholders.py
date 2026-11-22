"""Generate placeholder WAV files under assets/sfx/ for drop-in real audio.

Usage:
  python tools/generate_sfx_placeholders.py
  python tools/generate_sfx_placeholders.py --force
"""
from __future__ import annotations

import argparse
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sfx"

# kind -> list of (hz, ms)
TONES: dict[str, list[tuple[float, int]]] = {
	"ui": [(660, 45)],
	"pickup": [(740, 40), (880, 55), (1175, 70)],
	"clear": [(523, 70), (659, 80), (784, 110)],
	"adlib": [(988, 70), (1175, 80), (1319, 120)],
	"defeat": [(220, 120), (196, 140), (147, 180)],
	"victory": [(523, 80), (659, 90), (784, 90), (1047, 140)],
	"pause": [(330, 55)],
	"intro": [(440, 60), (554, 80)],
	"warn": [(370, 50), (311, 70)],
	"telegraph": [(415, 90)],
	"hazard": [(277, 60), (349, 80)],
	"setpiece": [(466, 55), (392, 70), (311, 90)],
	"phase": [(220, 70), (277, 80), (330, 70), (415, 110)],
	"solar": [(523, 55), (659, 70), (784, 95)],
	"moonbyul": [(392, 60), (494, 70), (587, 100)],
	"wheein": [(440, 50), (554, 65), (659, 80), (880, 70)],
	"hwasa": [(330, 45), (415, 55), (494, 70), (622, 110)],
	"hit": [(880, 35), (660, 40)],
	"boss": [(110, 80), (147, 90), (196, 120)],
}

RATE = 22050


def render(tones: list[tuple[float, int]]) -> bytes:
	samples: list[int] = []
	for hz, ms in tones:
		n = max(1, int(RATE * ms / 1000))
		for i in range(n):
			t = i / RATE
			env = 1.0 - i / n
			wave_v = math.sin(2 * math.pi * hz * t) * 0.30 + math.sin(4 * math.pi * hz * t) * 0.08
			samples.append(int(wave_v * env * 32767))
	return struct.pack("<" + "h" * len(samples), *samples)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--force", action="store_true")
	args = parser.parse_args()
	OUT.mkdir(parents=True, exist_ok=True)
	readme = OUT / "README.md"
	if not readme.exists() or args.force:
		readme.write_text(
			"# SFX slots\n\n"
			"Drop real `.wav` / `.ogg` with these names to replace procedural tones.\n"
			"`Sfx.play(kind)` loads `res://assets/sfx/{kind}.wav` first, then falls back.\n\n"
			"Generate placeholders: `python tools/generate_sfx_placeholders.py`\n",
			encoding="utf-8",
		)
	for kind, tones in TONES.items():
		path = OUT / f"{kind}.wav"
		if path.exists() and not args.force:
			continue
		data = render(tones)
		with wave.open(str(path), "w") as wf:
			wf.setnchannels(1)
			wf.setsampwidth(2)
			wf.setframerate(RATE)
			wf.writeframes(data)
		print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
	main()
