extends Control

func _on_button_pressed() -> void:
	GameState.voltando_da_loja = true
	get_tree().change_scene_to_file("res://scenes/cena_principal.tscn")
