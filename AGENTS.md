# AGENTS.md

## Project
- Godot 4 project (`project.godot`), GDScript, 2D top-down shooter.
- Main scene is `res://scenes/world/menu_principal.tscn` (title screen: Novo Jogo/Continuar/Sair). Novo Jogo/Continuar land on `res://scenes/world/selecao_de_cenario.tscn` (the hub), which routes to the gameplay zones — `res://scenes/world/zona_norte.tscn` (the original/complete level) and `res://scenes/world/zona_sul.tscn` (a playable skeleton with no tiles/enemies drawn yet). `res://scenes/world/cena_principal.tscn` is **not** part of that player flow: it's the dev/test scene (the origin `zona_norte.tscn` was duplicated from, used by `scripts/tests/player_vision_test.gd` and by a secret F3 shortcut on the hub) — see Gotchas below. Keep `run/main_scene` as a `res://` path, not a UID, so fresh clones run before Godot imports UIDs — the editor can rewrite it to `uid://` when saving Project Settings, so check `git diff project.godot` before committing.
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
- `scripts/core/save_slots.gd` (`class_name SaveSlots`, static-only): the save file mechanism — 4 independent slots (`user://save_auto.cfg` + `save_slot_1/2/3.cfg`, `ConfigFile` with a versioned `[meta]` envelope). Knows nothing about what a "game" is; only reads/writes opaque section dictionaries.
- `scripts/world/save_jogo.gd` (`class_name SaveJogo`, static-only): the save domain facade — builds/applies the save payload from `EstadoDoJogo`, tracks which slot (1-3) the current run is saving to (`static var`, survives `change_scene_to_file`), and is the single choke point for phase transitions (`trocar_fase`, `sair_para_o_menu`) so autosave-on-transition can't be forgotten at a new call site.
- `scripts/world/menu_principal.gd` + `scripts/world/selecao_de_save.gd`: the title screen and its reusable slot-selection panel (`enum Modo { NOVO_JOGO, CONTINUAR }`); the panel's buttons are generated in code from `SaveSlots.listar()`, not authored in the `.tscn`.
- `scripts/world/menu_pause.gd`: the ESC pause overlay, instanced in every playable scene (`zona_norte.tscn`, `zona_sul.tscn`, `cena_principal.tscn`, `loja.tscn`). Its `_unhandled_input` guard (`elif not get_tree().paused: ...`) is what keeps it from stealing ESC from `ZonaSaida`'s own `ConfirmationDialog`, which pauses the tree itself before popping up.
- `resources/tilesets/tileset_chao.tres` currently has no collision shapes.
- `resources/sprites/` holds sprite textures (by domain: `characters/`, `environment/`, `items/`, `test/`); `resources/sounds/` is reserved for future audio assets; `resources/tilesets/` holds `TileSet` resources.
- `scripts/world/selecao_de_cenario.gd`: the hub between the menu and the playable zones — two "cards" (Zona Norte / Zona Sul) generated in code from a `ZONAS` const, the same generated-buttons pattern as `selecao_de_save.gd`. Also owns the secret F3 dev shortcut (see Gotchas).
- `scripts/world/zona_populador.gd` (`class_name ZonaPopulador`, static-only): generates ~30 random `Ameaca` positions per zone (rejection sampling, avoiding the player spawn radius, obstacle overlap via `PhysicsUtils.is_position_clear`, **and** any candidate within `Ameaca.vision_range` that has clear line of sight to the player spawn via `PhysicsUtils.has_clear_line` — otherwise enemies could spawn already chasing the player with no movement/noise involved, especially in a zone with no walls painted yet like `zona_sul.tscn`) and holds the in-memory snapshot cache (`static var`, survives `change_scene_to_file`) of each zone's enemy state (`vivo`/`morto_com_corpo`/`looteado`) keyed by scene path. Knows nothing about `SaveSlots`/`ConfigFile` directly — `SaveJogo` is the only bridge to disk (see Save Schema). `RAIO_VISAO_INIMIGO` must be kept in sync with `Ameaca.vision_range`'s default.
- `scripts/world/zona_mundo_sync.gd`: one instance per playable zone scene (sibling of `Mundo`, `@export var cena_id`), in group `"zona_mundo_sync"`. On `_ready()` (after 2 physics frames, so colliders are registered either way), restores the zone from `ZonaPopulador`'s snapshot if one exists — via `ZonaPopulador.dar_folga_para_vivos_perto_da_saida`, which relocates any living `Ameaca` within `RAIO_FOLGA_AO_VOLTAR` (400px) of `ZonaSaida` so the player doesn't walk back in surrounded; dead corpses are never moved — or generates the first-visit population otherwise. `TestSpawner` was removed from `zona_norte.tscn`/`zona_sul.tscn` (redundant/confusing now that real population exists) — it only remains in `cena_principal.tscn`, the dev/test scene.
- `scenes/world/` holds level/screen scenes (`menu_principal.tscn`, `selecao_de_cenario.tscn` the hub, `zona_norte.tscn`/`zona_sul.tscn` the playable zones, `cena_principal.tscn` the dev/test scene, `loja.tscn`); `scenes/objects/` holds instantiable actor/prop scenes (`ameaca.tscn`, `barril.tscn`, `caixa.tscn`); `scenes/ui/` holds reusable overlays (`camada_ui.tscn`, `menu_pause.tscn`, `selecao_de_save.tscn`).
- `scripts/core/physics_utils.gd` (`class_name PhysicsUtils`, static-only): `has_clear_line`/`has_clear_motion` (raycast/shape-cast between two points) plus `is_position_clear` (point/shape overlap query, no motion) — used by `zona_populador.gd` to validate a candidate spawn position isn't inside a wall, since the wall tileset's per-tile collision data is too sparse to trust statically.

## Save Schema
- Sempre que uma nova funcionalidade precisar que algum dado sobreviva a
  save/load (não apenas durante a sessão em memória), siga este checklist,
  nesta ordem:
  1. Adicione o campo em `EstadoDoJogo.PADROES` (`scripts/world/game_state.gd`)
     com seu valor padrão, mais a `var` correspondente com o mesmo nome —
     `PADROES` é a fonte única tanto do default de partida nova quanto do
     schema persistido (`to_dict`/`from_dict` iteram sobre ele).
  2. Cubra o campo em `scripts/tests/save_jogo_test.gd`: pelo menos um teste
     de round-trip (`to_dict`→`from_dict` preserva o valor) e, se o campo tiver
     validação/fallback (como `cena` tem para `ResourceLoader.exists`), um
     teste do caminho de fallback.
  3. Atualize o Code Map deste arquivo e a seção relevante de `REVISAO.md`
     descrevendo o novo campo.
  Isto é uma prática permanente, não um lembrete pontual — vale para toda
  mudança futura que precise persistir estado, não só a que a introduziu.
- **Adendo — dados aninhados por zona (seção `"mundo"`)**: nem tudo cabe no
  modelo flat-escalar de `EstadoDoJogo.PADROES`. A população de `Ameaca` por
  zona (`ZonaPopulador`, `scripts/world/zona_populador.gd`) é uma segunda
  seção de save, irmã de `"estado"`, chamada `"mundo"`, com chave por caminho
  de cena e valor aninhado (`Array[Dictionary]`) — o `ConfigFile` do
  `SaveSlots` já suporta isso nativamente via encoding de Variant, sem
  nenhuma mudança em `save_slots.gd`. Se uma funcionalidade futura precisar de
  um formato igualmente não-flat, siga esse padrão em vez de forçar em
  `PADROES`: (1) uma fachada estática própria (como `ZonaPopulador`) com um
  cache em memória (`static var`); (2) uma nova chave de seção no dict de
  `SaveJogo._montar_secoes()`/lida em `_aplicar()`; (3) captura do estado ao
  vivo no mesmo gancho que já existe (`trocar_fase`/`autosalvar`), sem criar
  um novo ponto de disparo de save; (4) testes de round-trip e fallback em
  `save_jogo_test.gd`, iguais aos de campo flat, só que sobre a estrutura
  aninhada; (5) atualizar este Code Map e o `REVISAO.md`.

## Godot Gotchas
- Movement uses built-in `ui_up/down/left/right` actions plus WASD/setas/gamepad from `project.godot`.
- Keyboard `InputEventKey` entries must keep `device=-1`; specific device IDs can make `Input.get_axis()` return `0` on other keyboards.
- Shooting is action `shoot`, bound to left mouse button.
- `ui_cancel` (ESC) is not redefined in `project.godot`, so it's the Godot built-in — used to open/close the pause menu (`scripts/world/menu_pause.gd`). Don't rebind it without checking that guard logic.
- `crosshair.gd` sets `Input.mouse_mode = MOUSE_MODE_HIDDEN` in `_ready()` because the game draws its own crosshair; any screen that needs the system cursor (menus, the pause overlay, the loja) must set `MOUSE_MODE_VISIBLE` itself and restore the previous mode on the way out — `loja.gd` and `menu_pause.gd` do this; don't assume the cursor is visible by default.
- `get_tree().paused` survives `change_scene_to_file`; anything that navigates to a new scene (menu transitions, `SaveJogo.trocar_fase`/`sair_para_o_menu`) must despause first, or the new scene loads frozen.
- Enemy population per zone is dynamic and persistent: `ZonaMundoSync`/`ZonaPopulador` scatter ~30 `Ameaca` on first visit and snapshot alive/dead/looted state on every `SaveJogo.trocar_fase`/`autosalvar` — leaving for the loja and coming back, or closing and reopening the game, restores exactly what was there (dead stays dead, unlooted corpses stay put, looted ones don't come back). See `REVISAO.md` → "Menu Principal, Save e Pause".
- `aplicar_snapshot`'s "already dead" path (`Ameaca.spawn_como_corpo()`) must call `add_child()` **non-deferred**, then `spawn_como_corpo()` right after — `_ready()` unconditionally sets `health = max_health`, so if `add_child` were deferred (like `TestSpawner`'s pattern), `spawn_como_corpo()`'s `health = 0` would run before `_ready()` and get clobbered.
- F3 means two different things depending on the scene: inside a playable zone it's `scripts/noise/noise_visualizer.gd` (toggle the noise debug rings); on the hub (`selecao_de_cenario.tscn`) it's a secret dev shortcut straight to `cena_principal.tscn`, unrelated and undocumented for players. No runtime conflict (the hub has no `NoiseVisualizer`), but don't be surprised reading two different F3 handlers.
- Maintenance note: `zona_norte.tscn` and `cena_principal.tscn` are independent files that started identical (one was duplicated from the other) and can diverge — a gameplay fix made in one does not propagate to the other automatically. This is intentional (keeps the test scene stable), not an oversight.
- `REVISAO.md` is useful project context, but executable truth is `project.godot`, scenes, and scripts.

## Workflow
- Commit messages in history use Conventional Commit prefix in Portuguese, e.g. `feat: ...`, `fix: ...`, `refactor: ...`.
