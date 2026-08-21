extends Node
## Persistent device preferences. These settings deliberately live outside
## the gameplay save, so starting a new company does not reset language/audio.

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := ["tr", "en"]

var sound_effects_enabled := true
var music_enabled := true
var locale := "tr"
var _persist_enabled := true


func _ready() -> void:
	_persist_enabled = not OS.get_cmdline_user_args().has("--disable-auto-save")
	_install_translations()
	if _persist_enabled:
		_load_settings()
	_apply_all(false)


func set_sound_effects_enabled(enabled: bool) -> void:
	if sound_effects_enabled == enabled:
		return
	sound_effects_enabled = enabled
	_apply_audio_buses()
	_save_settings()
	EventBus.sound_effects_setting_changed.emit(sound_effects_enabled)


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return
	music_enabled = enabled
	_apply_audio_buses()
	_save_settings()
	EventBus.music_setting_changed.emit(music_enabled)


func set_locale(value: String) -> void:
	var normalized := value.to_lower().substr(0, 2)
	if not SUPPORTED_LOCALES.has(normalized):
		normalized = "tr"
	if locale == normalized:
		return
	locale = normalized
	TranslationServer.set_locale(locale)
	_save_settings()
	EventBus.language_changed.emit(locale)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var legacy_enabled := bool(config.get_value("audio", "enabled", true))
	sound_effects_enabled = bool(config.get_value("audio", "sound_effects_enabled", legacy_enabled))
	music_enabled = bool(config.get_value("audio", "music_enabled", legacy_enabled))
	var saved_locale := String(config.get_value("language", "locale", "tr"))
	locale = saved_locale if SUPPORTED_LOCALES.has(saved_locale) else "tr"


func _save_settings() -> void:
	if not _persist_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "sound_effects_enabled", sound_effects_enabled)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("language", "locale", locale)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save device settings: %s" % error)


func _apply_all(emit_signals: bool) -> void:
	TranslationServer.set_locale(locale)
	_apply_audio_buses()
	if emit_signals:
		EventBus.language_changed.emit(locale)
		EventBus.sound_effects_setting_changed.emit(sound_effects_enabled)
		EventBus.music_setting_changed.emit(music_enabled)


func _apply_audio_buses() -> void:
	_set_bus_muted("SFX", not sound_effects_enabled)
	_set_bus_muted("Music", not music_enabled)


func _set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_mute(bus_index, muted)


func _install_translations() -> void:
	_add_translation("tr", _turkish_messages())
	_add_translation("en", _english_messages())


func _add_translation(target_locale: String, messages: Dictionary) -> void:
	var translation := Translation.new()
	translation.locale = target_locale
	for key in messages.keys():
		translation.add_message(StringName(key), String(messages[key]))
	TranslationServer.add_translation(translation)


func _turkish_messages() -> Dictionary:
	return {
		"SETTINGS_TITLE": "Ayarlar",
		"SETTINGS_BUTTON": "⚙ Ayarlar",
		"SETTINGS_RESUME": "Devam Et",
		"SETTINGS_SFX_ON": "Ses Efektleri: Açık",
		"SETTINGS_SFX_OFF": "Ses Efektleri: Kapalı",
		"SETTINGS_MUSIC_ON": "Müzik: Açık",
		"SETTINGS_MUSIC_OFF": "Müzik: Kapalı",
		"SETTINGS_LANGUAGE": "Dil",
		"SETTINGS_LANGUAGE_TR": "Türkçe",
		"SETTINGS_LANGUAGE_EN": "English",
		"SETTINGS_NEW_GAME": "Yeni Oyuna Başla",
		"SETTINGS_NEW_GAME_TITLE": "Yeni oyuna başla",
		"SETTINGS_NEW_GAME_CONFIRM": "Tüm para, liman, gemi, görev ve şirket ilerlemesi kalıcı olarak silinecek.\nYeni oyuna başlamak istediğine emin misin?",
		"SETTINGS_NEW_GAME_OK": "Evet, ilerlemeyi sil",
		"SETTINGS_CANCEL": "Vazgeç",
		"SETTINGS_RESETTING": "Sıfırlanıyor...",
		"COMPANY_PROGRESS_MAX": "Şirket Sv. %d · %d CV · MAKS",
		"COMPANY_PROGRESS": "Şirket Sv. %d · %d / %d CV",
		"COMPANY_HEADQUARTERS": "Şirket Merkezi",
		"COMPANY_HEADQUARTERS_LEVEL": "Şirket Merkezi · Sv. %d",
		"DEBUG_LEVEL_UP": "TEST · Sv. %d → +1",
		"COMPANY_PANEL_TITLE": "Şirket İlerlemesi",
		"COMPANY_PANEL_LEVEL": "Şirket Seviyesi %d",
		"COMPANY_PANEL_TOTAL": "Toplam Şirket Değeri: %d CV",
		"COMPANY_PANEL_FLEET": "Filo: %d CV",
		"COMPANY_PANEL_PORTS": "Limanlar: %d CV",
		"COMPANY_PANEL_PROGRESS": "%d / %d CV · %d CV kaldı",
		"COMPANY_PANEL_NEXT_UNLOCKS": "Seviye %d'de açılacak: %s",
		"COMPANY_PANEL_NEXT_NONE": "Seviye %d için yeni içerik hazırlanıyor.",
		"COMPANY_PANEL_PORT_UNLOCK": "%s Limanı",
		"COMPANY_PANEL_SHIP_UNLOCK": "%s",
		"COMPANY_PANEL_MAX": "Maksimum şirket seviyesine ulaşıldı.",
		"COMPANY_PANEL_ALL_UNLOCKED": "Bütün mevcut şirket seviyesi ödülleri açıldı.",
		"COMPANY_PANEL_CLOSE": "Kapat",
		"PORT_UNLOCKED_LEVEL": "Sv. %d",
		"PORT_LOCKED_REQUIREMENTS": "Kilitli · Sv. %d · %d ₺",
		"PORT_UNLOCK_TITLE": "%s Limanı",
		"PORT_UNLOCK_DESCRIPTION_DEFAULT": "Yeni rotalar ve görev fırsatları açar.",
		"PORT_UNLOCK_LEVEL": "Gereken Şirket Seviyesi: %d · Mevcut: %d",
		"PORT_UNLOCK_COST": "Açma Bedeli: %d ₺ · Kasa: %d ₺",
		"PORT_UNLOCK_VALUE": "Şirket Değeri Katkısı: +%d CV",
		"PORT_UNLOCK_CONFIRM": "Limanı Aç · %d ₺",
		"PORT_UNLOCK_LEVEL_BLOCKED": "Şirket Sv. %d Gerekli",
		"PORT_UNLOCK_MONEY_BLOCKED": "%d ₺ Eksik",
		"PORT_UNLOCK_CANCEL": "Vazgeç",
		"FLEET_TITLE": "Filo Durumu",
		"SHIP_SHOP_TITLE": "Gemi Satın Al",
		"MISSION_OFFERS_TITLE": "%s limanındaki yükler",
		"MISSION_WAITING": "Görev bekleniyor...",
		"REMAINING": "Kalan: %s",
		"SHIP_DEFAULT": "Gemi",
		"AT_PORT": "Limanda: %s",
		"NO_CARGO": "Yük yok",
		"CARGO_LABEL": "Kargo: %s",
		"STATE_IDLE": "Boşta",
		"STATE_SAILING_TO_PICKUP": "Yük almaya gidiyor",
		"STATE_LOADING": "Yükleniyor",
		"STATE_SAILING_TO_DELIVERY": "Teslimata gidiyor",
		"STATE_UNLOADING": "Boşaltılıyor",
		"SPEED_MAX": "Hız maksimum · Sv.%d · %.0f hız",
		"SPEED_UPGRADE": "Hız Sv.%d · %.0f hız · %d ₺",
		"CAPACITY_MAX": "Kapasite maksimum · Sv.%d · %d birim",
		"CAPACITY_UPGRADE": "Kapasite Sv.%d · %d birim · %d ₺",
		"DURATION_SECONDS": "%d sn",
		"DURATION_MINUTES": "%d dk %02d sn",
		"SHOP_NOT_FOUND": "Gemi bulunamadı",
		"SHOP_DETAILS_GENERAL": "Hız: %d · Kapasite: %d\nGenel yük",
		"SHOP_DETAILS_REFRIGERATED": "Hız: %d · Kapasite: %d\nGenel + Soğutmalı yük",
		"SHOP_LEVEL_REQUIRED": "Şirket Sv. %d gerekli",
		"SHOP_CURRENT_LEVEL": "Şu anki seviye: %d",
		"SHOP_FLEET_FULL": "Filo kapasitesi dolu",
		"SHOP_FLEET_COUNT": "Filo: %d/%d",
		"SHOP_BUY": "Satın Al · %d ₺",
		"SHOP_OWNED": "Filoda: %d · Sonraki fiyat artar",
		"SHOP_SUCCESS": "Satın alma başarılı.",
		"SHOP_INSUFFICIENT": "Yetersiz bakiye: %d ₺ eksik",
		"INSTRUCTION_SELECT_SHIP": "Görevleri görmek için bir gemi seç.",
		"INSTRUCTION_SELECT_SHIP_LONG": "Görevleri görmek için haritadaki veya filo panelindeki bir gemiyi seç.",
		"INSTRUCTION_LEVEL_UP": "Şirket seviyesi %d oldu! Yeni içerikler açıldı.",
		"INSTRUCTION_LEVEL_REQUIRED": "Bu yatırım için Şirket Seviyesi %d gerekli (şu an %d).",
		"INSTRUCTION_MISSION_STARTED": "Görev başladı. Gemi rotasına otomatik ilerliyor.",
		"INSTRUCTION_TUTORIAL_COMPLETE": "ÖĞRETİCİ TAMAMLANDI · İlk görevin başladı; gemi otomatik ilerliyor.",
		"INSTRUCTION_SPEED_UPGRADED": "%s hız seviyesi %d oldu (%.0f hız).",
		"INSTRUCTION_CAPACITY_UPGRADED": "%s kapasite seviyesi %d oldu (%d birim).",
		"INSTRUCTION_UPGRADE_SHORT": "%s geliştirmesi için %d ₺ eksik.",
		"INSTRUCTION_FLEET_FULL": "Filo kapasitesi dolu: %d/%d gemi.",
		"INSTRUCTION_SHIP_SELECTED": "%s seçildi. Görev işareti bulunan bir limana dokun.",
		"INSTRUCTION_SHIP_BUSY": "%s şu anda görevde.",
		"INSTRUCTION_SELECT_SHIP_FIRST": "Önce görev vereceğin gemiyi seç.",
		"TUTORIAL_1_PURCHASE": "ÖĞRETİCİ 1/4 · Başlangıç Yük Gemisini satın al.",
		"TUTORIAL_2_SELECT_SHIP": "ÖĞRETİCİ 2/4 · Şirket merkezinde beliren gemiye dokun.",
		"TUTORIAL_3_NO_SHIP": "ÖĞRETİCİ 3/4 · Gemiyi seç, sonra görev işaretli bir limana dokun.",
		"TUTORIAL_3_SELECT_PORT": "ÖĞRETİCİ 3/4 · Görev işareti bulunan bir limana dokun.",
		"TUTORIAL_4_NO_PORT": "ÖĞRETİCİ 4/4 · Görev işaretli limana yeniden dokun.",
		"TUTORIAL_4_ACCEPT": "ÖĞRETİCİ 4/4 · Açılan tekliflerden bir görevi seç.",
		"INSTRUCTION_PORT_UNLOCKED": "%s limanı açıldı!",
		"INSTRUCTION_PORT_MONEY": "%s için %d ₺ gerekli. Eksik: %d ₺",
		"INSTRUCTION_SHIP_JOINED": "%s filoya katıldı!",
		"INSTRUCTION_OFFLINE": "Çevrimdışı ilerleme uygulandı: %d dakika.",
		"INSTRUCTION_NO_OFFERS": "Seçili gemi için bu limanda uygun görev yok.",
		"PORT_MERSIN": "Mersin", "PORT_IZMIR": "İzmir", "PORT_ISTANBUL": "İstanbul",
		"PORT_ANTALYA": "Antalya", "PORT_SAMSUN": "Samsun",
		"PORT_DESCRIPTION_ANTALYA": "İlk genişleme bölgesinin batı yük kapısı.",
		"PORT_DESCRIPTION_SAMSUN": "Daha uzun rotalara açılan ikinci bölgesel merkez.",
		"SHIP_STARTER_FREIGHTER": "Başlangıç Yük Gemisi",
		"SHIP_REFRIGERATED_FREIGHTER": "Soğutmalı Yük Gemisi",
		"CARGO_CONTAINERS": "Konteyner", "CARGO_FOOD": "Gıda",
		"CARGO_MACHINERY": "Makine Parçaları", "CARGO_METAL": "Metal",
	}


func _english_messages() -> Dictionary:
	var messages := _turkish_messages()
	messages.merge({
		"SETTINGS_TITLE": "Settings", "SETTINGS_BUTTON": "⚙ Settings",
		"SETTINGS_RESUME": "Resume", "SETTINGS_SFX_ON": "Sound Effects: On",
		"SETTINGS_SFX_OFF": "Sound Effects: Off", "SETTINGS_MUSIC_ON": "Music: On",
		"SETTINGS_MUSIC_OFF": "Music: Off", "SETTINGS_LANGUAGE": "Language",
		"SETTINGS_LANGUAGE_TR": "Türkçe", "SETTINGS_LANGUAGE_EN": "English",
		"SETTINGS_NEW_GAME": "Start New Game", "SETTINGS_NEW_GAME_TITLE": "Start a new game",
		"SETTINGS_NEW_GAME_CONFIRM": "All cash, ports, ships, missions, and company progress will be permanently deleted.\nAre you sure you want to start a new game?",
		"SETTINGS_NEW_GAME_OK": "Yes, delete progress", "SETTINGS_CANCEL": "Cancel",
		"SETTINGS_RESETTING": "Resetting...",
		"COMPANY_PROGRESS_MAX": "Company Lv. %d · %d CV · MAX",
		"COMPANY_PROGRESS": "Company Lv. %d · %d / %d CV",
		"COMPANY_HEADQUARTERS": "Company Headquarters",
		"COMPANY_HEADQUARTERS_LEVEL": "Company Headquarters · Lv. %d",
		"DEBUG_LEVEL_UP": "TEST · Lv. %d → +1",
		"COMPANY_PANEL_TITLE": "Company Progress", "COMPANY_PANEL_LEVEL": "Company Level %d",
		"COMPANY_PANEL_TOTAL": "Total Company Value: %d CV", "COMPANY_PANEL_FLEET": "Fleet: %d CV",
		"COMPANY_PANEL_PORTS": "Ports: %d CV", "COMPANY_PANEL_PROGRESS": "%d / %d CV · %d CV remaining",
		"COMPANY_PANEL_NEXT_UNLOCKS": "Unlocks at Level %d: %s",
		"COMPANY_PANEL_NEXT_NONE": "New content for Level %d is being prepared.",
		"COMPANY_PANEL_PORT_UNLOCK": "%s Port", "COMPANY_PANEL_SHIP_UNLOCK": "%s",
		"COMPANY_PANEL_MAX": "Maximum company level reached.",
		"COMPANY_PANEL_ALL_UNLOCKED": "All current company-level rewards are unlocked.",
		"COMPANY_PANEL_CLOSE": "Close",
		"PORT_UNLOCKED_LEVEL": "Lv. %d", "PORT_LOCKED_REQUIREMENTS": "Locked · Lv. %d · %d ₺",
		"PORT_UNLOCK_TITLE": "%s Port", "PORT_UNLOCK_DESCRIPTION_DEFAULT": "Unlocks new routes and mission opportunities.",
		"PORT_UNLOCK_LEVEL": "Required Company Level: %d · Current: %d",
		"PORT_UNLOCK_COST": "Unlock Cost: %d ₺ · Cash: %d ₺",
		"PORT_UNLOCK_VALUE": "Company Value Contribution: +%d CV",
		"PORT_UNLOCK_CONFIRM": "Unlock Port · %d ₺", "PORT_UNLOCK_LEVEL_BLOCKED": "Company Lv. %d Required",
		"PORT_UNLOCK_MONEY_BLOCKED": "%d ₺ Short", "PORT_UNLOCK_CANCEL": "Cancel",
		"FLEET_TITLE": "Fleet Status", "SHIP_SHOP_TITLE": "Buy Ship",
		"MISSION_OFFERS_TITLE": "Cargo at %s Port", "MISSION_WAITING": "Waiting for missions...",
		"REMAINING": "Remaining: %s", "SHIP_DEFAULT": "Ship", "AT_PORT": "At port: %s",
		"NO_CARGO": "No cargo", "CARGO_LABEL": "Cargo: %s", "STATE_IDLE": "Idle",
		"STATE_SAILING_TO_PICKUP": "Sailing to pickup", "STATE_LOADING": "Loading",
		"STATE_SAILING_TO_DELIVERY": "Sailing to delivery", "STATE_UNLOADING": "Unloading",
		"SPEED_MAX": "Speed max · Lv.%d · %.0f speed", "SPEED_UPGRADE": "Speed Lv.%d · %.0f speed · %d ₺",
		"CAPACITY_MAX": "Capacity max · Lv.%d · %d units", "CAPACITY_UPGRADE": "Capacity Lv.%d · %d units · %d ₺",
		"DURATION_SECONDS": "%d sec", "DURATION_MINUTES": "%d min %02d sec",
		"SHOP_NOT_FOUND": "Ship not found", "SHOP_DETAILS_GENERAL": "Speed: %d · Capacity: %d\nGeneral cargo",
		"SHOP_DETAILS_REFRIGERATED": "Speed: %d · Capacity: %d\nGeneral + Refrigerated cargo",
		"SHOP_LEVEL_REQUIRED": "Company Lv. %d required", "SHOP_CURRENT_LEVEL": "Current level: %d",
		"SHOP_FLEET_FULL": "Fleet capacity full", "SHOP_FLEET_COUNT": "Fleet: %d/%d",
		"SHOP_BUY": "Buy · %d ₺", "SHOP_OWNED": "Owned: %d · Next price increases",
		"SHOP_SUCCESS": "Purchase successful.", "SHOP_INSUFFICIENT": "Insufficient balance: %d ₺ short",
		"INSTRUCTION_SELECT_SHIP": "Select a ship to view missions.",
		"INSTRUCTION_SELECT_SHIP_LONG": "Select a ship on the map or in the fleet panel to view missions.",
		"INSTRUCTION_LEVEL_UP": "Company level reached %d! New content unlocked.",
		"INSTRUCTION_LEVEL_REQUIRED": "Company Level %d is required for this investment (currently %d).",
		"INSTRUCTION_MISSION_STARTED": "Mission started. The ship is sailing automatically.",
		"INSTRUCTION_TUTORIAL_COMPLETE": "TUTORIAL COMPLETE · Your first mission has started; the ship sails automatically.",
		"INSTRUCTION_SPEED_UPGRADED": "%s reached speed level %d (%.0f speed).",
		"INSTRUCTION_CAPACITY_UPGRADED": "%s reached capacity level %d (%d units).",
		"INSTRUCTION_UPGRADE_SHORT": "%s upgrade needs %d ₺ more.",
		"INSTRUCTION_FLEET_FULL": "Fleet capacity full: %d/%d ships.",
		"INSTRUCTION_SHIP_SELECTED": "%s selected. Tap a port with a mission marker.",
		"INSTRUCTION_SHIP_BUSY": "%s is currently on a mission.",
		"INSTRUCTION_SELECT_SHIP_FIRST": "Select the ship you want to assign first.",
		"TUTORIAL_1_PURCHASE": "TUTORIAL 1/4 · Purchase the Starter Freighter.",
		"TUTORIAL_2_SELECT_SHIP": "TUTORIAL 2/4 · Tap the ship delivered at Company Headquarters.",
		"TUTORIAL_3_NO_SHIP": "TUTORIAL 3/4 · Select the ship, then tap a port with a mission marker.",
		"TUTORIAL_3_SELECT_PORT": "TUTORIAL 3/4 · Tap a port with a mission marker.",
		"TUTORIAL_4_NO_PORT": "TUTORIAL 4/4 · Tap the marked port again.",
		"TUTORIAL_4_ACCEPT": "TUTORIAL 4/4 · Choose one of the mission offers.",
		"INSTRUCTION_PORT_UNLOCKED": "%s Port unlocked!",
		"INSTRUCTION_PORT_MONEY": "%s requires %d ₺. Short by: %d ₺",
		"INSTRUCTION_SHIP_JOINED": "%s joined the fleet!",
		"INSTRUCTION_OFFLINE": "Offline progress applied: %d minutes.",
		"INSTRUCTION_NO_OFFERS": "No suitable missions at this port for the selected ship.",
		"PORT_IZMIR": "Izmir", "PORT_ISTANBUL": "Istanbul",
		"PORT_DESCRIPTION_ANTALYA": "The western cargo gateway of the first expansion region.",
		"PORT_DESCRIPTION_SAMSUN": "A second regional hub opening the way to longer routes.",
		"SHIP_STARTER_FREIGHTER": "Starter Freighter", "SHIP_REFRIGERATED_FREIGHTER": "Refrigerated Freighter",
		"CARGO_CONTAINERS": "Containers", "CARGO_FOOD": "Food",
		"CARGO_MACHINERY": "Machinery Parts", "CARGO_METAL": "Metal",
	}, true)
	return messages
