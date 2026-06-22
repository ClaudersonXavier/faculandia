GODOT ?= godot

.PHONY: run editor test

run:
	$(GODOT) --path .

editor:
	$(GODOT) --path . --editor

test:
	$(GODOT) --path . --headless --script res://tests/player_vision_test.gd
