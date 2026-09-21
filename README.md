# Mech Junkyard — prototype

2.5D arena brawler in Godot 4.7. You pilot a scrappy mech in a junkyard arena.
Smash enemy mechs, rip parts off their wrecks, bolt them onto yourself mid-run.
Every limb changes your moveset — lose an arm and you're swinging bare wires.

## Controls

- **Move:** A/D or ←/→ (touch: left-half virtual joystick)
- **Jump:** W / ↑ / Space (touch: JUMP button)
- **Attack:** J / X (touch: ATK button)
- **Dash:** K / Shift / L — brief i-frames (touch: DASH button)

## Parts

**Arms** — Rusty Fist (default), Crusher Fist (slow huge slam + screen shake),
Buzzsaw (4-hit shredder), Scrap Cannon (ranged bolts). No arm = weak spark.

**Legs** — Basic, Turbo (+speed), Spring (double jump).

**Cores** — Armor (-35% damage), Regen (+3 HP/s), Magnet (parts fly to you).

Walk over a dropped part to equip it instantly; your old part pops off onto the
ground so you can swap back. Heavy hits (15+ dmg) have a 35% chance to rip your
arm clean off — go grab a new one.

## Waves

5 escalating waves: walkers → speeders → crushers. Wave clear heals +25 HP.
Enemies never drop nothing: every wreck bursts scrap and 1–2 parts.

## Run / test

```bash
GODOT=~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path ~/workspace/mech-junkyard --import   # once
$GODOT --headless --path ~/workspace/mech-junkyard -s res://tests/test_sim.gd
xvfb-run -a $GODOT --path ~/workspace/mech-junkyard --resolution 1280x720 -s res://tests/shots.gd
$GODOT --path ~/workspace/mech-junkyard   # play
```

No repo, no deploy — Jimmy handles GitHub himself.
