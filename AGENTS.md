# AGENTS.md

## Project
- Godot 4 project (`project.godot`), GDScript, 2D top-down shooter.
- Main scene is `res://scenes/world/menu_principal.tscn` (title screen: Novo Jogo/Continuar/Sair); the gameplay level is `res://scenes/world/cena_principal.tscn`. Keep `run/main_scene` as a `res://` path, not a UID, so fresh clones run before Godot imports UIDs — the editor can rewrite it to `uid://` when saving Project Settings, so check `git diff project.godot` before committing.
- Godot cache/import output lives in `.godot/` and is ignored; do not commit it.

## Commands
- Run game: `make run` (`godot --path .`).
- Open editor: `make editor` (`godot --path . --editor`).
- If Godot binary is not `godot`, override with `make run GODOT=/path/to/godot`.
- `make test` runs the headless suites in `scripts/tests/` (`--headless --script res://scripts/tests/*.gd`); each prints its own pass/fail and exits non-zero on failure. `scripts/tests/weapon_reload_hud_test.gd` is intentionally excluded from the `test` target (it conflicts with the `GameState` autoload being present).
- Headless `--script` runs need the project's global class cache populated first (`.godot/global_script_class_cache.cfg`); on a fresh clone, run `make editor` once (open and close is enough) before `make test`, or `class_name` types like `EstadoDoJogo`/`SaveJogo`/`SaveSlots` may fail to resolve.

## Code Map
- Scripts are organized by domain under `scripts/`: `player/`, `weapons/`, `enemies/`, `noise/`, `world/`, `testing/`, and `core/` (shared utilities used across domains). There is no `scripts/ui/`: UI scripts live in `scripts/world/` even when their scene is under `scenes/ui/` (e.g. `scripts/world/hud.gd` for `scenes/ui/camada_ui.tscn`) — follow that precedent for new UI rather than creating a `ui/` folder for a couple of files.
- `scripts/player/player_moviment.gd`: player movement, aiming, shooting trigger, camera-bound clamp.
- `scripts/player/player_vision.gd` + `scripts/player/player_vision_raycaster.gd`: raycast-based fog-of-war/vision cone; the raycaster holds the pure obstacle/ray geometry, `player_vision.gd` holds the public API, cone/light orchestration, and shader plumbing.
- `scripts/weapons/weapon.gd`: base weapon; creates bullets in code and attaches `scripts/weapons/bullet.gd`.
- `scripts/weapons/pistol.gd`: pistol stats via `Weapon` inheritance.
- `scripts/enemies/ameaca.gd`: enemy AI (direct-vision vs. navmesh chase); `scripts/enemies/ameaca_debug_logger.gd` holds its opt-in (`debug_logging`) diagnostics; `scripts/enemies/ameaca_debug_visualizer.gd` holds its F2 debug visualizer overlay.
- `scripts/noise/`: noise event bus (`noise_bus.gd`), event/synthesizer scripts, and SFX playback (`noise_sfx_player.gd`).
- `scripts/world/game_state.gd` (autoload `GameState`, `class_name EstadoDoJogo`): in-memory state of the current run — `PADROES` is the single source of truth for both the new-game defaults and the set of fields that get persisted (`to_dict`/`from_dict`/`reset`). Do not give it `class_name GameState`: a `class_name` identical to an autoload's name fails to compile in Godot 4.
- `scripts/core/save_slots.gd` (`class_name SaveSlots`, static-only): the save file mechanism — 4 independent slots (`user://save_auto.cfg` + `save_caixa_1/2/3.cfg`, `ConfigFile` with a versioned `[meta]` envelope). Knows nothing about what a "game" is; only reads/writes opaque section dictionaries.
- `scripts/world/save_jogo.gd` (`class_name SaveJogo`, static-only): the save domain facade — builds/applies the save payload from `EstadoDoJogo`, tracks which caixa (1-3) the current run is saving to (`static var`, survives `change_scene_to_file`), and is the single choke point for phase transitions (`trocar_fase`, `sair_para_o_menu`) so autosave-on-transition can't be forgotten at a new call site.
- `scripts/world/menu_principal.gd` + `scripts/world/selecao_de_save.gd`: the title screen and its reusable slot-selection panel (`enum Modo { NOVO_JOGO, CONTINUAR }`); the panel's buttons are generated in code from `SaveSlots.listar()`, not authored in the `.tscn`.
- `scripts/world/menu_pause.gd`: the ESC pause overlay, instanced in both `cena_principal.tscn` and `loja.tscn`. Its `_unhandled_input` guard (`elif not get_tree().paused: ...`) is what keeps it from stealing ESC from `ZonaSaida`'s own `ConfirmationDialog`, which pauses the tree itself before popping up.
- `resources/tilesets/tileset_chao.tres` currently has no collision shapes.
- `resources/sprites/` holds sprite textures (by domain: `characters/`, `environment/`, `items/`, `test/`); `resources/sounds/` is reserved for future audio assets; `resources/tilesets/` holds `TileSet` resources.
- `scenes/world/` holds level/screen scenes (`menu_principal.tscn`, `cena_principal.tscn`, `loja.tscn`); `scenes/objects/` holds instantiable actor/prop scenes (`ameaca.tscn`, `barril.tscn`, `caixa.tscn`); `scenes/ui/` holds reusable overlays (`camada_ui.tscn`, `menu_pause.tscn`, `selecao_de_save.tscn`).

## Godot Gotchas
- Movement uses built-in `ui_up/down/left/right` actions plus WASD/setas/gamepad from `project.godot`.
- Keyboard `InputEventKey` entries must keep `device=-1`; specific device IDs can make `Input.get_axis()` return `0` on other keyboards.
- Shooting is action `shoot`, bound to left mouse button.
- `ui_cancel` (ESC) is not redefined in `project.godot`, so it's the Godot built-in — used to open/close the pause menu (`scripts/world/menu_pause.gd`). Don't rebind it without checking that guard logic.
- `crosshair.gd` sets `Input.mouse_mode = MOUSE_MODE_HIDDEN` in `_ready()` because the game draws its own crosshair; any screen that needs the system cursor (menus, the pause overlay, the loja) must set `MOUSE_MODE_VISIBLE` itself and restore the previous mode on the way out — `loja.gd` and `menu_pause.gd` do this; don't assume the cursor is visible by default.
- `get_tree().paused` survives `change_scene_to_file`; anything that navigates to a new scene (menu transitions, `SaveJogo.trocar_fase`/`sair_para_o_menu`) must despause first, or the new scene loads frozen.
- Known limitation: leaving `cena_principal.tscn` for the loja and coming back reloads the level from the `.tscn`, so the two `Ameaca` instances (fixed in the editor, not spawned) respawn at full health and any un-looted Vestígio disappears — even though the save preserves money/ammo across that trip. See `REVISAO.md` → "Menu Principal, Save e Pause" for the two ways this gets fixed later.
- `REVISAO.md` is useful project context, but executable truth is `project.godot`, scenes, and scripts.

## Workflow
- Commit messages in history use Conventional Commit prefix in Portuguese, e.g. `feat: ...`, `fix: ...`, `refactor: ...`.
