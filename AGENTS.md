# AGENTS.md

## Project
- Godot 4 project (`project.godot`), GDScript, 2D top-down shooter.
- Main scene is `res://scenes/world/cena_principal.tscn`; keep `run/main_scene` as a `res://` path, not a UID, so fresh clones run before Godot imports UIDs.
- Godot cache/import output lives in `.godot/` and is ignored; do not commit it.

## Commands
- Run game: `make run` (`godot --path .`).
- Open editor: `make editor` (`godot --path . --editor`).
- If Godot binary is not `godot`, override with `make run GODOT=/path/to/godot`.
- No automated test/lint/typecheck config exists in this repo yet; verify gameplay changes by running through Godot.

## Code Map
- Scripts are organized by domain under `scripts/`: `player/`, `weapons/`, `enemies/`, `noise/`, `world/`, `testing/`, and `core/` (shared utilities used across domains).
- `scripts/player/player_moviment.gd`: player movement, aiming, shooting trigger, camera-bound clamp.
- `scripts/player/player_vision.gd` + `scripts/player/player_vision_raycaster.gd`: raycast-based fog-of-war/vision cone; the raycaster holds the pure obstacle/ray geometry, `player_vision.gd` holds the public API, cone/light orchestration, and shader plumbing.
- `scripts/weapons/weapon.gd`: base weapon; creates bullets in code and attaches `scripts/weapons/bullet.gd`.
- `scripts/weapons/pistol.gd`: pistol stats via `Weapon` inheritance.
- `scripts/enemies/ameaca.gd`: enemy AI (direct-vision vs. navmesh chase); `scripts/enemies/ameaca_debug_logger.gd` holds its opt-in (`debug_logging`) diagnostics.
- `scripts/noise/`: noise event bus (`noise_bus.gd`), event/synthesizer scripts, and SFX playback (`noise_sfx_player.gd`).
- `resources/tilesets/tileset_chao.tres` currently has no collision shapes.
- `resources/sprites/` holds sprite textures (by domain: `characters/`, `environment/`, `items/`, `test/`); `resources/sounds/` is reserved for future audio assets; `resources/tilesets/` holds `TileSet` resources.
- `scenes/world/` holds level/screen scenes (`cena_principal.tscn`, `loja.tscn`); `scenes/objects/` holds instantiable actor/prop scenes (`ameaca.tscn`, `barril.tscn`, `caixa.tscn`).

## Godot Gotchas
- Movement uses built-in `ui_up/down/left/right` actions plus WASD/setas/gamepad from `project.godot`.
- Keyboard `InputEventKey` entries must keep `device=-1`; specific device IDs can make `Input.get_axis()` return `0` on other keyboards.
- Shooting is action `shoot`, bound to left mouse button.
- `REVISAO.md` is useful project context, but executable truth is `project.godot`, scenes, and scripts.

## Workflow
- Commit messages in history use Conventional Commit prefix in Portuguese, e.g. `feat: ...`, `fix: ...`, `refactor: ...`.
