GODOT ?= godot
NVIDIA_ENV := __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only

.PHONY: run run-nvidia editor editor-nvidia test

run:
	$(GODOT) --path .

run-nvidia:
	$(NVIDIA_ENV) $(GODOT) --path .

editor:
	$(GODOT) --path . --editor

editor-nvidia:
	$(NVIDIA_ENV) $(GODOT) --path . --editor

test:
	$(GODOT) --path . --headless --script res://scripts/tests/player_movement_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/player_vision_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/noise_system_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/ameaca_test.gd
	$(GODOT) --path . --headless --script res://scripts/tests/navigation_integration_test.gd
