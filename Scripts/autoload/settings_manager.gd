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
		"EXIT_CONFIRM_TITLE": "Vardiya bitti mi, Kaptan?",
		"EXIT_CONFIRM_MESSAGE": "Filo güvenli ellerde, ama limanın ışıklarını kapatmak üzeresin.\nOyundan çıkmak istediğine emin misin?",
		"EXIT_CONFIRM_OK": "Evet, limanı kapat",
		"EXIT_CONFIRM_CANCEL": "Bir sefer daha!",
		"COMPANY_PROGRESS_MAX": "Şirket Sv. %d · %d CV · MAKS",
		"COMPANY_PROGRESS": "Şirket Sv. %d · %d / %d CV",
		"COMPANY_HEADQUARTERS": "Şirket Merkezi",
		"COMPANY_HEADQUARTERS_LEVEL": "Şirket Merkezi · Sv. %d",
		"DEBUG_LEVEL_UP": "TEST · Sv. %d → +1",
		"DEBUG_ADD_MONEY": "TEST · +10.000 ₺",
		"NEXT_GOAL_UNLOCK_PORT": "SONRAKİ HEDEF · %s Limanını aç · %d / %d ₺",
		"NEXT_GOAL_BUY_SHIP": "SONRAKİ HEDEF · %s satın al · %d / %d ₺",
		"NEXT_GOAL_REACH_LEVEL_FOR_PORT": "SONRAKİ HEDEF · %s için Şirket Sv. %d · %d / %d CV",
		"COMPANY_PANEL_TITLE": "Şirket İlerlemesi",
		"COMPANY_PANEL_LEVEL": "Şirket Seviyesi %d",
		"COMPANY_PANEL_TOTAL": "Toplam Şirket Değeri: %d CV",
		"COMPANY_PANEL_CV_EXPLANATION": "CV harcanabilen para değildir. Gemi ve liman yatırımlarıyla artar; şirket seviyelerini ve yeni içerikleri açar.",
		"COMPANY_VALUE_INFO_TITLE": "Şirket Değeri (CV)",
		"COMPANY_VALUE_INFO_OK": "Anladım",
		"COMPANY_PANEL_FLEET": "Filo: %d CV",
		"COMPANY_PANEL_PORTS": "Limanlar: %d CV",
		"COMPANY_PANEL_PROGRESS": "%d / %d CV · %d CV kaldı",
		"COMPANY_PANEL_NEXT_UNLOCKS": "Seviye %d'de açılacak: %s",
		"COMPANY_PANEL_NEXT_NONE": "Seviye %d için yeni içerik hazırlanıyor.",
		"COMPANY_PANEL_PORT_UNLOCK": "%s Limanı",
		"COMPANY_PANEL_SHIP_UNLOCK": "%s",
		"COMPANY_PANEL_FLEET_CAPACITY": "Filo kapasitesi: %d gemi",
		"COMPANY_PANEL_MAX": "Maksimum şirket seviyesine ulaşıldı.",
		"COMPANY_PANEL_ALL_UNLOCKED": "Bütün mevcut şirket seviyesi ödülleri açıldı.",
		"COMPANY_PANEL_CLOSE": "Kapat",
		"PORT_UNLOCKED_LEVEL": "Sv. %d",
		"PORT_LOCKED_REQUIREMENTS": "Kilitli · Sv. %d · %d ₺",
		"PORT_UNLOCK_TITLE": "%s Limanı",
		"PORT_UNLOCK_DESCRIPTION_DEFAULT": "Yeni rotalar ve görev fırsatları açar.",
		"PORT_UNLOCK_LEVEL": "Gereken Şirket Seviyesi: %d · Mevcut: %d",
		"PORT_BERTH_CAPACITY": "Gemi yuvası: %d",
		"PORT_BERTH_UPGRADE": "Gemi yuvası: %d → %d",
		"PORT_UNLOCK_COST": "Açma Bedeli: %d ₺ · Kasa: %d ₺",
		"PORT_UNLOCK_VALUE": "Şirket Değeri Katkısı: +%d CV",
		"PORT_UNLOCK_CONFIRM": "Limanı Aç · %d ₺",
		"PORT_UNLOCK_LEVEL_BLOCKED": "Şirket Sv. %d Gerekli",
		"PORT_UNLOCK_MONEY_BLOCKED": "%d ₺ Eksik",
		"PORT_UNLOCK_CANCEL": "Vazgeç",
		"PORT_UPGRADE_TITLE": "%s Limanı · Sv. %d",
		"PORT_UPGRADE_BENEFITS": "Yeni seviye · Liman geliri +%%%d · Yük işlemleri %%%d daha hızlı",
		"PORT_UPGRADE_MAX_BENEFITS": "Liman tamamlandı · Liman geliri +%%%d · Yük işlemleri %%%d daha hızlı",
		"PORT_UPGRADE_LEVEL": "Liman Seviyesi: %d → %d",
		"PORT_UPGRADE_MAX_LEVEL": "Liman Seviyesi: %d · MAKS",
		"PORT_UPGRADE_COST": "Geliştirme Bedeli: %d ₺ · Kasa: %d ₺",
		"PORT_UPGRADE_VALUE": "Şirket Değeri Katkısı: +%d CV",
		"PORT_UPGRADE_TOTAL_VALUE": "Toplam Liman Değeri: %d CV",
		"PORT_UPGRADE_CONFIRM": "Limanı Geliştir · %d ₺",
		"PORT_UPGRADE_MONEY_BLOCKED": "%d ₺ Eksik",
		"PORT_UPGRADE_COMPLETE": "Tüm geliştirmeler tamamlandı.",
		"PORT_UPGRADE_MAX_BUTTON": "Maksimum Seviye",
		"PORT_UPGRADE_CLOSE": "Kapat",
		"FLEET_TITLE": "Filo Durumu",
		"FLEET_TAB_TITLE": "Filo %d/%d",
		"FLEET_SUMMARY": "%d/%d gemi · %d boşta · %d görevde",
		"FLEET_LIST_TITLE": "Gemiler",
		"FLEET_SELECT_HINT": "Ayrıntıları görmek için bir gemi seç.",
		"FLEET_CURRENT_ROUTE": "Rota: %s",
		"FLEET_CURRENT_CARGO": "%s",
		"FLEET_LIFETIME_STATS": "%d görev tamamladı · Toplam net: %d ₺",
		"FLEET_RENAME_ACTION": "İsim Değiştir",
		"FLEET_HELP_TITLE": "Filo Durumu",
		"FLEET_HELP_MESSAGE": "Gemini seç, takip et ve geliştir.\nHız süreyi kısaltır; kapasite yükü artırır.\nOtomatik Görev: Sv.5 + 3 görev + 5.000 ₺. Yeni işi yalnızca oyun açıkken seçer.",
		"FLEET_HELP_OK": "Anladım",
		"SHIP_SHOP_TITLE": "Gemi Satın Al",
		"MISSION_OFFERS_TITLE": "%s limanındaki yükler",
		"MISSION_WAITING": "Görev bekleniyor...",
		"MISSION_FINANCIALS": "NET +%d ₺ · Brüt %d · Masraf -%d",
		"REMAINING": "Kalan: %s",
		"SHIP_DEFAULT": "Gemi",
		"SHIP_RENAME_BUTTON": "Geminin adını değiştir",
		"SHIP_RENAME_TITLE": "Geminin Adını Değiştir",
		"SHIP_RENAME_PLACEHOLDER": "Gemi adı",
		"SHIP_RENAME_RANDOM": "Rastgele isim öner",
		"SHIP_RENAME_OK": "Kaydet",
		"SHIP_RENAME_CANCEL": "Vazgeç",
		"SHIP_RENAME_LENGTH_ERROR": "Gemi adı %d–%d karakter olmalı.",
		"SHIP_RENAME_DUPLICATE_ERROR": "Bu isim filodaki başka bir gemide kullanılıyor.",
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
		"AUTOMATION_ON": "Otomatik Görev: Açık",
		"AUTOMATION_OFF": "Otomatik Görev: Kapalı",
		"AUTOMATION_LEVEL_REQUIRED": "Otomatik Görev · Şirket Sv.%d",
		"AUTOMATION_MISSIONS_REQUIRED": "Otomatik Görev · Görev %d/%d",
		"AUTOMATION_UNLOCK": "Otomatik Görevi Aç · %d ₺",
		"DURATION_SECONDS": "%d sn",
		"DURATION_MINUTES": "%d dk %02d sn",
		"SHOP_NOT_FOUND": "Gemi bulunamadı",
		"SHOP_DETAILS_GENERAL": "Hız: %d · Kapasite: %d\nGenel yük",
		"SHOP_DETAILS_REFRIGERATED": "Hız: %d · Kapasite: %d\nGenel + Soğutmalı yük",
		"SHOP_DETAILS_BULK": "Hız: %d · Kapasite: %d\nDökme yük",
		"SHOP_LEVEL_REQUIRED": "Şirket Sv. %d gerekli",
		"SHOP_CURRENT_LEVEL": "Şu anki seviye: %d",
		"SHOP_FLEET_FULL": "Filo kapasitesi dolu",
		"SHOP_FLEET_COUNT": "Filo: %d/%d",
		"SHOP_FLEET_NEXT_LEVEL": "Filo: %d/%d · Şirket Sv. %d'de kapasite %d",
		"SHOP_FLEET_MAX": "Filo: %d/%d · Maksimum kapasite",
		"SHOP_BUY": "Satın Al · %d ₺",
		"SHOP_OWNED": "Filo: %d/%d · Her alım tüm fiyatları artırır",
		"SHOP_SUCCESS": "Satın alma başarılı.",
		"SHOP_INSUFFICIENT": "Yetersiz bakiye: %d ₺ eksik",
		"INSTRUCTION_SELECT_SHIP": "Görevleri görmek için bir gemi seç.",
		"INSTRUCTION_SELECT_SHIP_LONG": "Görevleri görmek için haritadaki veya filo panelindeki bir gemiyi seç.",
		"INSTRUCTION_LEVEL_UP": "Şirket seviyesi %d oldu! Yeni içerikler açıldı.",
		"INSTRUCTION_LEVEL_REQUIRED": "Bu yatırım için Şirket Seviyesi %d gerekli (şu an %d).",
		"INSTRUCTION_MISSION_STARTED": "Görev başladı. Gemi rotasına otomatik ilerliyor.",
		"INSTRUCTION_MISSION_COMPLETED": "Teslimat tamamlandı · Net +%d ₺ (%d gelir -%d masraf).",
		"INSTRUCTION_AUTOMATION_READY": "%s otomatik göreve hazır · Filo panelinden %d ₺ karşılığında açabilirsin.",
		"INSTRUCTION_TUTORIAL_COMPLETE": "ÖĞRETİCİ TAMAMLANDI · İlk görevin başladı; gemi otomatik ilerliyor.",
		"INSTRUCTION_TUTORIAL_SKIPPED": "ÖĞRETİCİ ATLANDI · Hazır olduğunda şirketini kendi planına göre büyütebilirsin.",
		"INSTRUCTION_SPEED_UPGRADED": "%s hız seviyesi %d oldu (%.0f hız).",
		"INSTRUCTION_CAPACITY_UPGRADED": "%s kapasite seviyesi %d oldu (%d birim).",
		"INSTRUCTION_UPGRADE_SHORT": "%s geliştirmesi için %d ₺ eksik.",
		"INSTRUCTION_FLEET_FULL": "Filo kapasitesi dolu: %d/%d gemi.",
		"INSTRUCTION_SHIP_SELECTED": "%s seçildi. Görev işareti bulunan bir limana dokun.",
		"INSTRUCTION_SHIP_BUSY": "%s şu anda görevde.",
		"INSTRUCTION_SELECT_SHIP_FIRST": "Önce görev vereceğin gemiyi seç.",
		"TUTORIAL_1_OPEN_SHOP": "ÖĞRETİCİ 1/8 · Yanıp sönen Gemi Satın Al sekmesine dokun.",
		"TUTORIAL_2_PURCHASE": "ÖĞRETİCİ 2/8 · Başlangıç Yük Gemisini satın al.",
		"TUTORIAL_3_OPEN_COMPANY_PROGRESS": "ÖĞRETİCİ 3/8 · Sarı CV göstergesine dokun ve Şirket İlerlemesini aç.",
		"TUTORIAL_4_READ_COMPANY_VALUE": "ÖĞRETİCİ 4/8 · Paneldeki ? düğmesine dokun ve CV açıklamasını oku.",
		"TUTORIAL_4_REOPEN_COMPANY_PROGRESS": "ÖĞRETİCİ 4/8 · CV göstergesine dokunup paneli yeniden aç.",
		"TUTORIAL_5_SELECT_SHIP": "ÖĞRETİCİ 5/8 · Şirket merkezinde beliren gemiye dokun.",
		"TUTORIAL_6_NO_SHIP": "ÖĞRETİCİ 6/8 · Gemiyi seç, sonra görev işaretli bir limana dokun.",
		"TUTORIAL_6_SELECT_PORT": "ÖĞRETİCİ 6/8 · Görev işareti bulunan bir limana dokun.",
		"TUTORIAL_7_NO_PORT": "ÖĞRETİCİ 7/8 · Görev işaretli limana yeniden dokun.",
		"TUTORIAL_7_ACCEPT": "ÖĞRETİCİ 7/8 · Açılan tekliflerden bir görevi seç.",
		"TUTORIAL_8_WELCOME": "ÖĞRETİCİ 8/8 · İlk görevin yola çıktı. Hazırsın Kaptan!",
		"TUTORIAL_COMPLETE_TITLE": "Hazırsın Kaptan!",
		"TUTORIAL_COMPLETE_MESSAGE": "İlk görevin yola çıktı. Filonu büyüt, yeni limanlar aç ve denizlerde kendi şirketini kur. İyi eğlenceler!",
		"TUTORIAL_SKIP_CAPTAIN_MESSAGE": "Öğreticiyi atlayarak serbest oyuna geçiyorsun. Başlangıç paran ve açık limanlarınla kendi rotanı çizmeye hazırsın. İyi eğlenceler Kaptan!",
		"TUTORIAL_COMPLETE_OK": "Denizlere Açıl!",
		"TUTORIAL_SKIP": "Öğreticiyi Atla",
		"INSTRUCTION_PORT_UNLOCKED": "%s limanı açıldı!",
		"INSTRUCTION_PORT_UPGRADED": "%s limanı seviye %d oldu!",
		"INSTRUCTION_PORT_MONEY": "%s için %d ₺ gerekli. Eksik: %d ₺",
		"INSTRUCTION_SHIP_JOINED": "%s filoya katıldı!",
		"INSTRUCTION_SHIP_RENAMED": "Geminin yeni adı: %s",
		"INSTRUCTION_OFFLINE": "Çevrimdışı ilerleme uygulandı: %d dakika.",
		"OFFLINE_SUMMARY_TITLE": "Sen yokken...",
		"OFFLINE_SUMMARY_MESSAGE": "Filo çalışmaya devam etti.\n%d sefer tamamlandı · +%d ₺",
		"OFFLINE_SUMMARY_OK": "Haritaya Dön",
		"INSTRUCTION_NO_OFFERS": "Seçili gemi için bu limanda uygun görev yok.",
		"PORT_MERSIN": "Mersin", "PORT_IZMIR": "İzmir", "PORT_ISTANBUL": "İstanbul",
		"PORT_ANTALYA": "Antalya", "PORT_SAMSUN": "Samsun",
		"PORT_CANAKKALE": "Çanakkale", "PORT_TRABZON": "Trabzon", "PORT_PIRE": "Pire",
		"PORT_VARNA": "Varna",
		"PORT_BATUM": "Batum",
		"PORT_GIRNE": "Girne",
		"PORT_ISKENDERIYE": "İskenderiye",
		"PORT_DESCRIPTION_ANTALYA": "İlk genişleme bölgesinin batı yük kapısı.",
		"PORT_DESCRIPTION_SAMSUN": "Daha uzun rotalara açılan ikinci bölgesel merkez.",
		"PORT_DESCRIPTION_CANAKKALE": "Ege ile Marmara arasındaki bölgesel geçiş limanı.",
		"PORT_DESCRIPTION_TRABZON": "Uzak Karadeniz rotalarına açılan doğu bölge merkezi.",
		"PORT_DESCRIPTION_PIRE": "Batı adalarına ve yeni Akdeniz rotalarına açılan dış ticaret limanı.",
		"PORT_DESCRIPTION_VARNA": "Kuzey adasını bölgesel ağa bağlayan uzak Karadeniz ticaret limanı.",
		"PORT_DESCRIPTION_BATUM": "Doğu adasını Karadeniz ağına bağlayan ileri bölge ticaret limanı.",
		"PORT_DESCRIPTION_GIRNE": "Güneydoğu adasının kuzey kıyısını ana bölgesel ağa bağlayan liman.",
		"PORT_DESCRIPTION_ISKENDERIYE": "Güney denizlerini doğu ticaret ağına bağlayan prestij limanı.",
		"SHIP_STARTER_FREIGHTER": "Başlangıç Yük Gemisi",
		"SHIP_REFRIGERATED_FREIGHTER": "Soğutmalı Yük Gemisi",
		"SHIP_BULK_CARRIER": "Dökme Yük Gemisi",
		"CARGO_CONTAINERS": "Konteyner", "CARGO_FOOD": "Gıda",
		"CARGO_MACHINERY": "Makine Parçaları", "CARGO_METAL": "Metal",
		"CARGO_GRAIN": "Tahıl",
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
		"EXIT_CONFIRM_TITLE": "Calling it a day, Captain?",
		"EXIT_CONFIRM_MESSAGE": "The fleet is in safe hands, but you're about to turn off the harbor lights.\nAre you sure you want to quit?",
		"EXIT_CONFIRM_OK": "Yes, close the harbor",
		"EXIT_CONFIRM_CANCEL": "One more voyage!",
		"COMPANY_PROGRESS_MAX": "Company Lv. %d · %d CV · MAX",
		"COMPANY_PROGRESS": "Company Lv. %d · %d / %d CV",
		"COMPANY_HEADQUARTERS": "Company Headquarters",
		"COMPANY_HEADQUARTERS_LEVEL": "Company Headquarters · Lv. %d",
		"DEBUG_LEVEL_UP": "TEST · Lv. %d → +1",
		"DEBUG_ADD_MONEY": "TEST · +10,000 ₺",
		"NEXT_GOAL_UNLOCK_PORT": "NEXT GOAL · Unlock %s Port · %d / %d ₺",
		"NEXT_GOAL_BUY_SHIP": "NEXT GOAL · Buy %s · %d / %d ₺",
		"NEXT_GOAL_REACH_LEVEL_FOR_PORT": "NEXT GOAL · %s at Company Lv. %d · %d / %d CV",
		"COMPANY_PANEL_TITLE": "Company Progress", "COMPANY_PANEL_LEVEL": "Company Level %d",
		"COMPANY_PANEL_TOTAL": "Total Company Value: %d CV", "COMPANY_PANEL_FLEET": "Fleet: %d CV",
		"COMPANY_PANEL_CV_EXPLANATION": "CV is not spendable cash. It grows through ship and port investments, unlocking company levels and new content.",
		"COMPANY_VALUE_INFO_TITLE": "Company Value (CV)", "COMPANY_VALUE_INFO_OK": "Got it",
		"COMPANY_PANEL_PORTS": "Ports: %d CV", "COMPANY_PANEL_PROGRESS": "%d / %d CV · %d CV remaining",
		"COMPANY_PANEL_NEXT_UNLOCKS": "Unlocks at Level %d: %s",
		"COMPANY_PANEL_NEXT_NONE": "New content for Level %d is being prepared.",
		"COMPANY_PANEL_PORT_UNLOCK": "%s Port", "COMPANY_PANEL_SHIP_UNLOCK": "%s",
		"COMPANY_PANEL_FLEET_CAPACITY": "Fleet capacity: %d ships",
		"COMPANY_PANEL_MAX": "Maximum company level reached.",
		"COMPANY_PANEL_ALL_UNLOCKED": "All current company-level rewards are unlocked.",
		"COMPANY_PANEL_CLOSE": "Close",
		"PORT_UNLOCKED_LEVEL": "Lv. %d", "PORT_LOCKED_REQUIREMENTS": "Locked · Lv. %d · %d ₺",
		"PORT_UNLOCK_TITLE": "%s Port", "PORT_UNLOCK_DESCRIPTION_DEFAULT": "Unlocks new routes and mission opportunities.",
		"PORT_UNLOCK_LEVEL": "Required Company Level: %d · Current: %d",
		"PORT_BERTH_CAPACITY": "Ship berths: %d", "PORT_BERTH_UPGRADE": "Ship berths: %d → %d",
		"PORT_UNLOCK_COST": "Unlock Cost: %d ₺ · Cash: %d ₺",
		"PORT_UNLOCK_VALUE": "Company Value Contribution: +%d CV",
		"PORT_UNLOCK_CONFIRM": "Unlock Port · %d ₺", "PORT_UNLOCK_LEVEL_BLOCKED": "Company Lv. %d Required",
		"PORT_UNLOCK_MONEY_BLOCKED": "%d ₺ Short", "PORT_UNLOCK_CANCEL": "Cancel",
		"PORT_UPGRADE_TITLE": "%s Port · Lv. %d",
		"PORT_UPGRADE_BENEFITS": "Next level · Port income +%%%d · Cargo handling %%%d faster",
		"PORT_UPGRADE_MAX_BENEFITS": "Port complete · Port income +%%%d · Cargo handling %%%d faster",
		"PORT_UPGRADE_LEVEL": "Port Level: %d → %d", "PORT_UPGRADE_MAX_LEVEL": "Port Level: %d · MAX",
		"PORT_UPGRADE_COST": "Upgrade Cost: %d ₺ · Cash: %d ₺",
		"PORT_UPGRADE_VALUE": "Company Value Contribution: +%d CV",
		"PORT_UPGRADE_TOTAL_VALUE": "Total Port Value: %d CV",
		"PORT_UPGRADE_CONFIRM": "Upgrade Port · %d ₺", "PORT_UPGRADE_MONEY_BLOCKED": "%d ₺ Short",
		"PORT_UPGRADE_COMPLETE": "All upgrades completed.", "PORT_UPGRADE_MAX_BUTTON": "Maximum Level",
		"PORT_UPGRADE_CLOSE": "Close",
		"FLEET_TITLE": "Fleet Status",
		"FLEET_TAB_TITLE": "Fleet %d/%d",
		"FLEET_SUMMARY": "%d/%d ships · %d idle · %d working",
		"FLEET_LIST_TITLE": "Ships",
		"FLEET_SELECT_HINT": "Select a ship to view its details.",
		"FLEET_CURRENT_ROUTE": "Route: %s",
		"FLEET_CURRENT_CARGO": "%s",
		"FLEET_LIFETIME_STATS": "%d missions completed · Lifetime net: %d ₺",
		"FLEET_RENAME_ACTION": "Rename",
		"FLEET_HELP_TITLE": "Fleet Status",
		"FLEET_HELP_MESSAGE": "Select, track and improve your ship.\nSpeed shortens trips; capacity increases cargo.\nAuto Dispatch: Lv.5 + 3 missions + 5,000 ₺. It only picks new jobs while the game is open.",
		"FLEET_HELP_OK": "Got it",
		"SHIP_SHOP_TITLE": "Buy Ship",
		"MISSION_OFFERS_TITLE": "Cargo at %s Port", "MISSION_WAITING": "Waiting for missions...",
		"MISSION_FINANCIALS": "NET +%d ₺ · Gross %d · Cost -%d",
		"REMAINING": "Remaining: %s", "SHIP_DEFAULT": "Ship", "AT_PORT": "At port: %s",
		"SHIP_RENAME_BUTTON": "Rename ship", "SHIP_RENAME_TITLE": "Rename Ship",
		"SHIP_RENAME_PLACEHOLDER": "Ship name", "SHIP_RENAME_RANDOM": "Suggest a random name",
		"SHIP_RENAME_OK": "Save", "SHIP_RENAME_CANCEL": "Cancel",
		"SHIP_RENAME_LENGTH_ERROR": "Ship name must be %d–%d characters.",
		"SHIP_RENAME_DUPLICATE_ERROR": "Another ship in the fleet already uses this name.",
		"NO_CARGO": "No cargo", "CARGO_LABEL": "Cargo: %s", "STATE_IDLE": "Idle",
		"STATE_SAILING_TO_PICKUP": "Sailing to pickup", "STATE_LOADING": "Loading",
		"STATE_SAILING_TO_DELIVERY": "Sailing to delivery", "STATE_UNLOADING": "Unloading",
		"SPEED_MAX": "Speed max · Lv.%d · %.0f speed", "SPEED_UPGRADE": "Speed Lv.%d · %.0f speed · %d ₺",
		"CAPACITY_MAX": "Capacity max · Lv.%d · %d units", "CAPACITY_UPGRADE": "Capacity Lv.%d · %d units · %d ₺",
		"AUTOMATION_ON": "Auto Dispatch: On", "AUTOMATION_OFF": "Auto Dispatch: Off",
		"AUTOMATION_LEVEL_REQUIRED": "Auto Dispatch · Company Lv.%d",
		"AUTOMATION_MISSIONS_REQUIRED": "Auto Dispatch · Missions %d/%d",
		"AUTOMATION_UNLOCK": "Unlock Auto Dispatch · %d ₺",
		"DURATION_SECONDS": "%d sec", "DURATION_MINUTES": "%d min %02d sec",
		"SHOP_NOT_FOUND": "Ship not found", "SHOP_DETAILS_GENERAL": "Speed: %d · Capacity: %d\nGeneral cargo",
		"SHOP_DETAILS_REFRIGERATED": "Speed: %d · Capacity: %d\nGeneral + Refrigerated cargo",
		"SHOP_DETAILS_BULK": "Speed: %d · Capacity: %d\nBulk cargo",
		"SHOP_LEVEL_REQUIRED": "Company Lv. %d required", "SHOP_CURRENT_LEVEL": "Current level: %d",
		"SHOP_FLEET_FULL": "Fleet capacity full", "SHOP_FLEET_COUNT": "Fleet: %d/%d",
		"SHOP_FLEET_NEXT_LEVEL": "Fleet: %d/%d · Company Lv. %d: capacity %d",
		"SHOP_FLEET_MAX": "Fleet: %d/%d · Maximum capacity",
		"SHOP_BUY": "Buy · %d ₺", "SHOP_OWNED": "Fleet: %d/%d · Every purchase raises all prices",
		"SHOP_SUCCESS": "Purchase successful.", "SHOP_INSUFFICIENT": "Insufficient balance: %d ₺ short",
		"INSTRUCTION_SELECT_SHIP": "Select a ship to view missions.",
		"INSTRUCTION_SELECT_SHIP_LONG": "Select a ship on the map or in the fleet panel to view missions.",
		"INSTRUCTION_LEVEL_UP": "Company level reached %d! New content unlocked.",
		"INSTRUCTION_LEVEL_REQUIRED": "Company Level %d is required for this investment (currently %d).",
		"INSTRUCTION_MISSION_STARTED": "Mission started. The ship is sailing automatically.",
		"INSTRUCTION_MISSION_COMPLETED": "Delivery complete · Net +%d ₺ (%d income -%d cost).",
		"INSTRUCTION_AUTOMATION_READY": "%s is ready for Auto Dispatch · Unlock it from the Fleet panel for %d ₺.",
		"INSTRUCTION_TUTORIAL_COMPLETE": "TUTORIAL COMPLETE · Your first mission has started; the ship sails automatically.",
		"INSTRUCTION_TUTORIAL_SKIPPED": "TUTORIAL SKIPPED · Grow the company at your own pace when you are ready.",
		"INSTRUCTION_SPEED_UPGRADED": "%s reached speed level %d (%.0f speed).",
		"INSTRUCTION_CAPACITY_UPGRADED": "%s reached capacity level %d (%d units).",
		"INSTRUCTION_UPGRADE_SHORT": "%s upgrade needs %d ₺ more.",
		"INSTRUCTION_FLEET_FULL": "Fleet capacity full: %d/%d ships.",
		"INSTRUCTION_SHIP_SELECTED": "%s selected. Tap a port with a mission marker.",
		"INSTRUCTION_SHIP_BUSY": "%s is currently on a mission.",
		"INSTRUCTION_SELECT_SHIP_FIRST": "Select the ship you want to assign first.",
		"TUTORIAL_1_OPEN_SHOP": "TUTORIAL 1/8 · Tap the pulsing Buy Ship tab.",
		"TUTORIAL_2_PURCHASE": "TUTORIAL 2/8 · Purchase the Starter Freighter.",
		"TUTORIAL_3_OPEN_COMPANY_PROGRESS": "TUTORIAL 3/8 · Tap the yellow CV display to open Company Progress.",
		"TUTORIAL_4_READ_COMPANY_VALUE": "TUTORIAL 4/8 · Tap the ? button and read the CV explanation.",
		"TUTORIAL_4_REOPEN_COMPANY_PROGRESS": "TUTORIAL 4/8 · Tap the CV display to reopen Company Progress.",
		"TUTORIAL_5_SELECT_SHIP": "TUTORIAL 5/8 · Tap the ship delivered at Company Headquarters.",
		"TUTORIAL_6_NO_SHIP": "TUTORIAL 6/8 · Select the ship, then tap a port with a mission marker.",
		"TUTORIAL_6_SELECT_PORT": "TUTORIAL 6/8 · Tap a port with a mission marker.",
		"TUTORIAL_7_NO_PORT": "TUTORIAL 7/8 · Tap the marked port again.",
		"TUTORIAL_7_ACCEPT": "TUTORIAL 7/8 · Choose one of the mission offers.",
		"TUTORIAL_8_WELCOME": "TUTORIAL 8/8 · Your first mission is underway. You're ready, Captain!",
		"TUTORIAL_COMPLETE_TITLE": "You're Ready, Captain!",
		"TUTORIAL_COMPLETE_MESSAGE": "Your first mission is underway. Grow your fleet, unlock new ports, and build your own company across the seas. Have fun!",
		"TUTORIAL_SKIP_CAPTAIN_MESSAGE": "You're entering free play by skipping the tutorial. With your starting cash and unlocked ports, you're ready to chart your own course. Have fun, Captain!",
		"TUTORIAL_COMPLETE_OK": "Set Sail!",
		"TUTORIAL_SKIP": "Skip Tutorial",
		"INSTRUCTION_PORT_UNLOCKED": "%s Port unlocked!",
		"INSTRUCTION_PORT_UPGRADED": "%s Port reached level %d!",
		"INSTRUCTION_PORT_MONEY": "%s requires %d ₺. Short by: %d ₺",
		"INSTRUCTION_SHIP_JOINED": "%s joined the fleet!",
		"INSTRUCTION_SHIP_RENAMED": "The ship's new name is %s.",
		"INSTRUCTION_OFFLINE": "Offline progress applied: %d minutes.",
		"OFFLINE_SUMMARY_TITLE": "While You Were Away...",
		"OFFLINE_SUMMARY_MESSAGE": "Your fleet kept working.\n%d voyages completed · +%d ₺",
		"OFFLINE_SUMMARY_OK": "Return to Map",
		"INSTRUCTION_NO_OFFERS": "No suitable missions at this port for the selected ship.",
		"PORT_IZMIR": "Izmir", "PORT_ISTANBUL": "Istanbul",
		"PORT_CANAKKALE": "Canakkale", "PORT_TRABZON": "Trabzon", "PORT_PIRE": "Piraeus",
		"PORT_VARNA": "Varna",
		"PORT_BATUM": "Batumi",
		"PORT_GIRNE": "Kyrenia",
		"PORT_ISKENDERIYE": "Alexandria",
		"PORT_DESCRIPTION_ANTALYA": "The western cargo gateway of the first expansion region.",
		"PORT_DESCRIPTION_SAMSUN": "A second regional hub opening the way to longer routes.",
		"PORT_DESCRIPTION_CANAKKALE": "A regional gateway between the Aegean and Marmara.",
		"PORT_DESCRIPTION_TRABZON": "An eastern regional hub opening distant Black Sea routes.",
		"PORT_DESCRIPTION_PIRE": "A foreign-trade port opening the western islands and new Mediterranean routes.",
		"PORT_DESCRIPTION_VARNA": "A distant Black Sea trade port connecting the northern island to the regional network.",
		"PORT_DESCRIPTION_BATUM": "An advanced trade port connecting the eastern island to the Black Sea network.",
		"PORT_DESCRIPTION_GIRNE": "A port connecting the northern coast of the southeastern island to the regional network.",
		"PORT_DESCRIPTION_ISKENDERIYE": "A prestige port connecting the southern seas to the eastern trade network.",
		"SHIP_STARTER_FREIGHTER": "Starter Freighter", "SHIP_REFRIGERATED_FREIGHTER": "Refrigerated Freighter",
		"SHIP_BULK_CARRIER": "Bulk Carrier",
		"CARGO_CONTAINERS": "Containers", "CARGO_FOOD": "Food",
		"CARGO_MACHINERY": "Machinery Parts", "CARGO_METAL": "Metal", "CARGO_GRAIN": "Grain",
	}, true)
	return messages
