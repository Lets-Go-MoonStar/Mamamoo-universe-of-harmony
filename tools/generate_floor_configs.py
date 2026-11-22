"""Emit resources/floor_configs/floor_4.tres .. floor_13.tres from the GDD bands."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "resources" / "floor_configs"

EARLY = [
	"res://resources/enemy_pool/echo.tres",
	"res://resources/enemy_pool/echo_swift.tres",
	"res://resources/enemy_pool/feedback.tres",
	"res://resources/enemy_pool/mute.tres",
]
MID = [
	"res://resources/enemy_pool/echo_armored.tres",
	"res://resources/enemy_pool/tuner.tres",
	"res://resources/enemy_pool/echo_corrupted.tres",
	"res://resources/enemy_pool/echo_elite.tres",
]
LATE = [
	"res://resources/enemy_pool/feedback_elite.tres",
	"res://resources/enemy_pool/mute_elite.tres",
]
EXTRA = [
	"res://resources/enemy_pool/resonance_drone.tres",
	"res://resources/enemy_pool/pulse_swarm.tres",
	"res://resources/enemy_pool/hex_echo.tres",
	"res://resources/enemy_pool/mirror_siren.tres",
	"res://resources/enemy_pool/beat_crusher.tres",
	"res://resources/enemy_pool/tempo_snare.tres",
	"res://resources/enemy_pool/choir_shade.tres",
	"res://resources/enemy_pool/grav_anchor.tres",
	"res://resources/enemy_pool/stage_marshal.tres",
	"res://resources/enemy_pool/lane_diva.tres",
	"res://resources/enemy_pool/rift_caller.tres",
]


def enemy_pool(n: int) -> list[str]:
	pool = list(EARLY)
	if n >= 2:
		pool += MID[:2]
	if n >= 3:
		pool += MID[2:]
	if n >= 4:
		pool += LATE
		pool.append(EXTRA[2])
	if n >= 5:
		pool.append(EXTRA[0])
		pool.append(EXTRA[5])
	if n >= 6:
		pool.append(EXTRA[1])
		pool.append(EXTRA[6])
		pool.append(EXTRA[8])
	if n >= 7:
		pool.append(EXTRA[3])
		pool.append(EXTRA[7])
		pool.append(EXTRA[9])
	if n >= 8:
		pool.append(EXTRA[4])
		pool.append(EXTRA[10])
	return pool


def boss_pool(n: int) -> list[str]:
	bosses: list[str] = []
	if n <= 2:
		bosses.append("res://resources/boss_pool/overlord.tres")
	if 2 <= n <= 4:
		bosses.append("res://resources/boss_pool/critic.tres")
	if 3 <= n <= 4:
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if 5 <= n <= 7:
		bosses.append("res://resources/boss_pool/crystal_warden.tres")
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if 8 <= n <= 10:
		bosses.append("res://resources/boss_pool/void_conductor.tres")
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if n >= 11:
		bosses.append("res://resources/boss_pool/void_conductor.tres")
		bosses.append("res://resources/boss_pool/void_conductor.tres")
		bosses.append("res://resources/boss_pool/eclipse.tres")
	return bosses or ["res://resources/boss_pool/eclipse.tres"]


def bands(n: int) -> dict:
	if n <= 2:
		return dict(
			min_rooms=7,
			max_rooms=10,
			enemy_budget=5 if n == 1 else 6,
			elite_chance=0.14 if n == 1 else 0.17,
			event_chance=0.14,
			shop_chance=0.15,
			reward_chance=0.15,
			route_branch_chance=0.50 if n == 1 else 0.55,
		)
	if n <= 7:
		return dict(
			min_rooms=10,
			max_rooms=15,
			enemy_budget=7 + (n - 3) // 2,
			elite_chance=round(0.20 + (n - 3) * 0.015, 3),
			event_chance=0.16,
			shop_chance=0.17,
			reward_chance=0.16,
			route_branch_chance=0.58,
		)
	return dict(
		min_rooms=14 + (n - 8),
		max_rooms=18 + (n - 8),
		enemy_budget=10 + (n - 8),
		elite_chance=round(0.30 + (n - 8) * 0.015, 3),
		event_chance=0.20,
		shop_chance=0.16,
		reward_chance=0.18,
		route_branch_chance=0.64,
	)


def fmt_array(paths: list[str]) -> str:
	inner = ", ".join(f'"{p}"' for p in paths)
	return f"Array[String]([{inner}])"


def emit(n: int) -> str:
	b = bands(n)
	diff = 1.0 + (n - 1) * 0.08
	dmg = 1.0 + (n - 1) * 0.055
	return f"""[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/floor_config.gd" id="1"]

[resource]
script = ExtResource("1")
floor_number = {n}
min_rooms = {b['min_rooms']}
max_rooms = {b['max_rooms']}
difficulty_multiplier = {diff:.3f}
damage_multiplier = {dmg:.3f}
enemy_budget = {b['enemy_budget']}
elite_chance = {b['elite_chance']}
event_chance = {b['event_chance']}
shop_chance = {b['shop_chance']}
reward_chance = {b['reward_chance']}
boss_pool = {fmt_array(boss_pool(n))}
enemy_pool = {fmt_array(enemy_pool(n))}
biome_index = {(n - 1) % 9}
route_branch_chance = {b['route_branch_chance']}
"""


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for n in range(4, 14):
		path = OUT / f"floor_{n}.tres"
		path.write_text(emit(n), encoding="utf-8")
		print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
	main()
