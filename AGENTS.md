# AGENTS.md

## Project
- Godot 4 project (`project.godot`), GDScript, 2D top-down shooter.
- Main scene is `res://scenes/cena_principal.tscn`; keep `run/main_scene` as a `res://` path, not a UID, so fresh clones run before Godot imports UIDs.
- Godot cache/import output lives in `.godot/` and is ignored; do not commit it.

## Commands
- Run game: `make run` (`godot --path .`).
- Open editor: `make editor` (`godot --path . --editor`).
- If Godot binary is not `godot`, override with `make run GODOT=/path/to/godot`.
- No automated test/lint/typecheck config exists in this repo yet; verify gameplay changes by running through Godot.

## Code Map
- `scripts/player_moviment.gd`: player movement, aiming, shooting trigger, camera-bound clamp, vision cone helper.
- `scripts/weapon.gd`: base weapon; creates bullets in code and attaches `scripts/bullet.gd`.
- `scripts/pistol.gd`: pistol stats via `Weapon` inheritance.
- `scripts/visibilidade.gd` + `shaders/visao_conica.gdshader`: fog/vision cone.
- `resources/tileset_chao.tres` currently has no collision shapes.

## Godot Gotchas
- Movement uses built-in `ui_up/down/left/right` actions plus WASD/setas/gamepad from `project.godot`.
- Keyboard `InputEventKey` entries must keep `device=-1`; specific device IDs can make `Input.get_axis()` return `0` on other keyboards.
- Shooting is action `shoot`, bound to left mouse button.
- `REVISAO.md` is useful project context, but executable truth is `project.godot`, scenes, and scripts.

## Workflow
- Commit messages in history use Conventional Commit prefix in Portuguese, e.g. `feat: ...`, `fix: ...`, `refactor: ...`.
