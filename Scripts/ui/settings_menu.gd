class_name SettingsMenu
extends Control

signal menu_opened()
signal resumed()
signal sound_effects_toggled(enabled: bool)
signal music_toggled(enabled: bool)
signal locale_selected(locale: String)
signal new_game_confirmed()

@onready var _settings_button: Button = $SettingsButton
@onready var _overlay: ColorRect = $Overlay
@onready var _title: Label = $Overlay/Center/Panel/Margin/VBox/Title
@onready var _resume_button: Button = $Overlay/Center/Panel/Margin/VBox/ResumeButton
@onready var _sound_effects_button: Button = $Overlay/Center/Panel/Margin/VBox/SoundEffectsButton
@onready var _music_button: Button = $Overlay/Center/Panel/Margin/VBox/MusicButton
@onready var _language_label: Label = $Overlay/Center/Panel/Margin/VBox/LanguageLabel
@onready var _language_select: OptionButton = $Overlay/Center/Panel/Margin/VBox/LanguageSelect
@onready var _new_game_button: Button = $Overlay/Center/Panel/Margin/VBox/NewGameButton
@onready var _confirmation_dialog: ConfirmationDialog = $ConfirmationDialog

var _sound_effects_enabled := true
var _music_enabled := true
var _locale := "tr"


func _ready() -> void:
	_settings_button.pressed.connect(open_menu)
	_resume_button.pressed.connect(close_menu)
	_sound_effects_button.pressed.connect(_on_sound_effects_pressed)
	_music_button.pressed.connect(_on_music_pressed)
	_language_select.item_selected.connect(_on_language_selected)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_confirmation_dialog.confirmed.connect(_on_new_game_confirmed)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	_refresh_texts()
	_overlay.hide()


func set_preferences(
		sound_effects_enabled: bool,
		music_enabled: bool,
		locale: String
) -> void:
	_sound_effects_enabled = sound_effects_enabled
	_music_enabled = music_enabled
	_locale = locale
	_refresh_texts()


func open_menu() -> void:
	_overlay.show()
	_settings_button.hide()
	menu_opened.emit()


func close_menu() -> void:
	_overlay.hide()
	_settings_button.show()
	resumed.emit()


func is_open() -> bool:
	return _overlay.visible


func _on_sound_effects_pressed() -> void:
	_sound_effects_enabled = not _sound_effects_enabled
	_refresh_audio_texts()
	sound_effects_toggled.emit(_sound_effects_enabled)


func _on_music_pressed() -> void:
	_music_enabled = not _music_enabled
	_refresh_audio_texts()
	music_toggled.emit(_music_enabled)


func _on_language_selected(index: int) -> void:
	var selected_locale := String(_language_select.get_item_metadata(index))
	if selected_locale == "" or selected_locale == _locale:
		return
	_locale = selected_locale
	locale_selected.emit(_locale)


func _on_new_game_pressed() -> void:
	_confirmation_dialog.popup_centered(Vector2i(560, 260))


func _on_new_game_confirmed() -> void:
	_new_game_button.disabled = true
	_new_game_button.text = tr("SETTINGS_RESETTING")
	new_game_confirmed.emit()


func _on_language_changed(locale: String) -> void:
	_locale = locale
	_refresh_texts()


func _refresh_texts() -> void:
	_settings_button.text = tr("SETTINGS_BUTTON")
	_title.text = tr("SETTINGS_TITLE")
	_resume_button.text = tr("SETTINGS_RESUME")
	_language_label.text = tr("SETTINGS_LANGUAGE")
	_new_game_button.text = tr("SETTINGS_NEW_GAME")
	_confirmation_dialog.title = tr("SETTINGS_NEW_GAME_TITLE")
	_confirmation_dialog.dialog_text = tr("SETTINGS_NEW_GAME_CONFIRM")
	_confirmation_dialog.ok_button_text = tr("SETTINGS_NEW_GAME_OK")
	_confirmation_dialog.cancel_button_text = tr("SETTINGS_CANCEL")
	_refresh_audio_texts()
	_refresh_language_options()


func _refresh_audio_texts() -> void:
	_sound_effects_button.text = tr(
		"SETTINGS_SFX_ON" if _sound_effects_enabled else "SETTINGS_SFX_OFF"
	)
	_music_button.text = tr(
		"SETTINGS_MUSIC_ON" if _music_enabled else "SETTINGS_MUSIC_OFF"
	)


func _refresh_language_options() -> void:
	_language_select.clear()
	_language_select.add_item(tr("SETTINGS_LANGUAGE_TR"))
	_language_select.set_item_metadata(0, "tr")
	_language_select.add_item(tr("SETTINGS_LANGUAGE_EN"))
	_language_select.set_item_metadata(1, "en")
	_language_select.select(1 if _locale == "en" else 0)
