extends Node
## Versioned JSON save/load and offline progress coordinator.

const SAVE_VERSION := 1
const SAVE_PATH := "user://savegame.json"
const AUTOSAVE_INTERVAL_SEC := 10.0

var _auto_enabled := true
var _autosave_timer: Timer


func _ready() -> void:
	_auto_enabled = not OS.get_cmdline_user_args().has("--disable-auto-save")
	if not _auto_enabled:
		return
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)
	call_deferred("_load_or_start")


func _notification(what: int) -> void:
	if not _auto_enabled:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func delete_save(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func reset_game() -> bool:
	if not delete_save():
		push_error("Could not delete the current save game.")
		return false

	MissionManager.reset_state()
	FleetManager.reset_state()
	PortManager.reset_state()
	CompanyManager.reset_state()
	GameManager.reset_state()

	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		push_error("Could not reload the main scene after resetting the game.")
		return false
	await get_tree().process_frame
	MissionManager.refresh_offers()
	EventBus.game_loaded.emit()
	return true


func save_game(path: String = SAVE_PATH) -> bool:
	var save_data := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"game": GameManager.get_save_state(),
		"ports": PortManager.get_save_state(),
		"fleet": FleetManager.get_save_state(),
		"missions": MissionManager.get_save_state(),
		"company": CompanyManager.get_save_state(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: %s" % path)
		return false
	file.store_string(JSON.stringify(save_data))
	file.close()
	EventBus.game_saved.emit()
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open save file for reading: %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("Save file is not valid JSON data: %s" % path)
		return false
	if int(parsed.get("version", 0)) != SAVE_VERSION:
		push_error("Unsupported save version: %s" % parsed.get("version", 0))
		return false

	GameManager.apply_save_state(parsed.get("game", {}))
	PortManager.apply_save_state(parsed.get("ports", {}))
	FleetManager.apply_save_state(parsed.get("fleet", {}))
	MissionManager.apply_save_state(parsed.get("missions", {}))
	MissionManager.sync_active_missions_from_fleet()
	CompanyManager.apply_save_state(parsed.get("company", {}))

	var now := Time.get_unix_time_from_system()
	var saved_at := float(parsed.get("saved_at_unix", now))
	var elapsed := maxf(now - saved_at, 0.0)
	FleetManager.apply_offline_progress(now)
	MissionManager.refresh_offers()
	EventBus.offline_progress_applied.emit(float(elapsed))
	EventBus.game_loaded.emit()
	return true


func _load_or_start() -> void:
	if not load_game():
		EventBus.game_loaded.emit()
