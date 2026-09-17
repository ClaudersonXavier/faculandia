GODOT ?= godot
NVIDIA_ENV := __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only
CACHE_FILE := .godot/global_script_class_cache.cfg

.PHONY: run run-nvidia editor editor-nvidia test setup

setup:
	@./scripts/setup_godot.sh $(GODOT)

$(CACHE_FILE):
	@./scripts/setup_godot.sh $(GODOT)

run: $(CACHE_FILE)
	$(GODOT) --path .

run-nvidia: $(CACHE_FILE)
	$(NVIDIA_ENV) $(GODOT) --path .

editor:
	$(GODOT) --path . --editor

editor-nvidia:
	$(NVIDIA_ENV) $(GODOT) --path . --editor

test: $(CACHE_FILE)
	$(GODOT) --path . --headless --script res://scripts/tests/player_movement_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/player_health_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/player_vision_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/noise_system_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/ameaca_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/navigation_integration_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/save_jogo_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/zona_populador_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/upgrades_pistola_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/upgrades_shotgun_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/weapon_switching_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/weapon_reload_hud_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/musica_tema_test.gd
