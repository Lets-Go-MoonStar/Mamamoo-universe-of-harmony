"""Generate minimal valid PNG placeholders for every res://assets/*.png referenced by .gd scripts.

The real art pack was never uploaded to GitHub. These placeholders unblock Godot
preload/import so the prototype can run until the real assets are restored.
"""
from __future__ import annotations

import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def png_bytes(width: int, height: int, rgba: tuple[int, int, int, int] = (40, 40, 60, 255)) -> bytes:
	r, g, b, a = rgba
	raw = b"".join(b"\x00" + bytes([r, g, b, a]) * width for _ in range(height))

	def chunk(tag: bytes, data: bytes) -> bytes:
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

	return (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)


def size_for(rel: str) -> tuple[int, int, tuple[int, int, int, int]]:
	rel = rel.replace("\\", "/")
	if "/backgrounds/" in rel or rel.endswith("_background.png"):
		return 1280, 720, (28, 24, 48, 255)
	if "/characters/" in rel or ("/enemies/" in rel and "spritesheet" in rel):
		return 1024, 1536, (70, 50, 90, 255)
	if "/bosses/" in rel and "spritesheet" in rel:
		return 1024, 1536, (90, 40, 60, 255)
	if "portraits" in rel:
		return 512, 128, (90, 70, 40, 255)
	if "member_frames" in rel:
		return 256, 256, (50, 50, 70, 255)
	if "ui_hud" in rel or "ui_menus" in rel:
		return 1024, 1024, (30, 40, 55, 255)
	if "/items/" in rel:
		return 1254, 1254, (45, 55, 40, 255)
	if "projectiles" in rel or "combat_effects" in rel or "status_effects" in rel:
		return 512, 512, (80, 60, 30, 255)
	if "elemental_abilities" in rel:
		return 456, 1400, (60, 40, 100, 255)
	if "abilities_atlas" in rel:
		return 1024, 1024, (100, 40, 40, 255)
	if "map_icons" in rel or "status_and_map" in rel:
		return 384, 384, (40, 60, 80, 255)
	if "rewards_and_card" in rel:
		return 1254, 1254, (50, 45, 35, 255)
	if "tileset" in rel or "/tiles/" in rel or "architecture" in rel:
		return 1024, 1024, (35, 45, 55, 255)
	if "overview" in rel:
		return 1024, 512, (55, 35, 70, 255)
	return 640, 360, (35, 35, 45, 255)


def collect_paths() -> set[str]:
	paths: set[str] = set()
	for path in ROOT.rglob("*.gd"):
		text = path.read_text(encoding="utf-8", errors="replace")
		for match in re.finditer(r'res://(assets/[^"\']+\.png)', text):
			paths.add(match.group(1))
	return paths


def main() -> None:
	paths = collect_paths()
	created = 0
	skipped = 0
	for rel in sorted(paths):
		out = ROOT / rel
		if out.exists() and out.stat().st_size > 0:
			skipped += 1
			continue
		out.parent.mkdir(parents=True, exist_ok=True)
		width, height, color = size_for(rel)
		out.write_bytes(png_bytes(width, height, color))
		created += 1
		print(f"+ {rel} ({width}x{height})")
	print(f"required={len(paths)} created={created} skipped_existing={skipped}")


if __name__ == "__main__":
	main()
