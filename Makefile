GODOT ?= godot

.PHONY: run editor

run:
	$(GODOT) --path .

editor:
	$(GODOT) --path . --editor
