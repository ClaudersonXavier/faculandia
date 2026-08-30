extends Area2D

@onready var dialog: ConfirmationDialog = %ConfirmationDialog 

func _ready() -> void:
	dialog.get_cancel_button().pressed.connect(_on_confirmation_dialog_canceled)
	dialog.close_requested.connect(_on_confirmation_dialog_canceled)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		dialog.popup_centered()

func _on_confirmation_dialog_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/loja.tscn")

func _on_confirmation_dialog_canceled() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().paused = false
