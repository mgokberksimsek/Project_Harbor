extends Button

@onready var _confirmation_dialog: ConfirmationDialog = $ConfirmationDialog


func _ready() -> void:
	pressed.connect(_on_pressed)
	_confirmation_dialog.confirmed.connect(_on_confirmed)


func _on_pressed() -> void:
	_confirmation_dialog.popup_centered(Vector2i(520, 220))


func _on_confirmed() -> void:
	disabled = true
	text = "Sıfırlanıyor..."
	SaveManager.reset_game()
