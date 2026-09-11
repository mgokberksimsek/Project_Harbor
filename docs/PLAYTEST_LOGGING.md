# Progression Playtest Logging

Bu araç Level 1–8 denge koşularında Android debug build'in ürettiği
`PH_PLAYTEST` logcat satırlarını PC'de CSV ve Markdown raporlarına dönüştürür.
Production analytics değildir; ağ, SDK, oyun içi popup veya gameplay save alanı
eklemez.

## İzolasyon ve süreklilik

- `ProgressionPlaytestLogger` yalnız `OS.is_debug_build()` true olduğunda
  dinamik olarak yüklenir. Release build logger script'ini yüklemez, dosya
  yazmaz ve log üretmez.
- Gameplay verisi `user://savegame.json` içinde değişmeden kalır. Save version
  değişmez.
- Debug logger, uygulama yeniden açıldığında aynı fresh-save koşusuna devam
  edebilmek için ayrı bir `user://progression_playtest_state.json` dosyası
  tutar. Bu dosya yalnız milestone tekilliği, süre ve raporlama sayaçlarıdır;
  gameplay tarafından okunmaz.
- `New Game`, yeni bir run başlatır ve `GAME_STARTED` üretir. Eski save'in
  normal yüklenmesi yeni run başlatmaz.
- `--disable-playtest-logger` argümanı debug logger'ı açıkça devre dışı bırakır.

## 1. Android cihazı bağlama

Telefonda Developer options ve USB debugging'i açın. USB kablosunu bağlayın ve
telefonda görünen RSA/USB debugging onayını kabul edin.

ADB PATH üzerinde değilse Android SDK'daki `platform-tools` klasörünü PATH'e
ekleyin veya aşağıdaki watcher komutuna `--adb` ile tam yolu verin.
Watcher ayrıca Godot 4.x editor ayarlarındaki Android SDK yolunu otomatik arar.

## 2. ADB doğrulama

Repository kökünde PowerShell açın:

```powershell
adb devices
```

Çıktıda tek cihazın yanında `device` yazmalıdır. `unauthorized` görünürse
telefon ekranındaki onayı kabul edip komutu yeniden çalıştırın.

Birden fazla cihaz varsa seri numarasını not edin; watcher'a
`--serial SERIAL` ekleyin.

## 3. Watcher'ı başlatma

Oyunu açmadan önce ayrı bir PowerShell terminalinde:

```powershell
python tools/progression_playtest_logger.py
```

ADB PATH üzerinde değilse örnek:

```powershell
python tools/progression_playtest_logger.py --adb "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
```

Bu çalışma alanında doğrulanan SDK yolu kullanılıyorsa kesin komut:

```powershell
python tools/progression_playtest_logger.py --adb "C:\Users\gokbe\Documents\Codex\2026-07-30\ben\work\AndroidToolchain\android-sdk\platform-tools\adb.exe" --serial SCYT99UCBICI6HHI
```

Watcher yalnız logcat'i dinler; oyunu başlatmaz, durdurmaz veya kontrol etmez.
İlk `PH_PLAYTEST` kaydı geldiğinde çıktı klasörünü terminale yazar.

## 4. Debug APK'yı kurma ve açma

Godot 4.7.2 Editor'da **Project > Export > Android > Export Project** ile debug
APK üretilebilir. CLI kullanılıyorsa, Godot executable yolunu kendi kurulumunuza
göre değiştirin:

```powershell
& "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --export-debug Android build/android/ProjectHarbor-debug.apk
adb install -r build/android/ProjectHarbor-debug.apk
adb shell monkey -p com.gokberksimsek.projectharbor -c android.intent.category.LAUNCHER 1
```

`adb install -r` mevcut uygulama verisini korur. Tamamen temiz cihaz verisi
isteniyorsa aşağıdaki komut save ve ayarlar dahil uygulamanın bütün yerel
verisini siler; yalnız bunu gerçekten istediğinizde çalıştırın:

```powershell
adb shell pm clear com.gokberksimsek.projectharbor
adb install -r build/android/ProjectHarbor-debug.apk
adb shell monkey -p com.gokberksimsek.projectharbor -c android.intent.category.LAUNCHER 1
```

## 5. Fresh-save koşusunu başlatma

Oyunda Settings menüsünü açın, **New Game** seçeneğini onaylayın. Watcher
terminalinde sırasıyla `EVENT GAME_STARTED` ve `MILESTONE GAME_STARTED`
görünmelidir. Eski save'i yalnız açmak `GAME_STARTED` üretmez.

Temiz kurulumda save yoksa oyun ilk açılışta otomatik olarak fresh run başlatır.

## 6. Normal oynama

Oyunu normal progression akışıyla oynayın. Watcher şunları otomatik kaydeder:

- normal mission ve Large Contract tamamlanması;
- ship purchase, port unlock;
- ship speed/capacity ve port upgrade;
- automation unlock/enable/disable;
- Company Level değişimleri;
- istenen Level 1–8 milestone'ları.

Uygulama background'a giderken active time durur. Elapsed time fresh run'ın Unix
başlangıcından itibaren devam eder. Cold-load sırasında tamamlanan offline
mission'lar `completed_offline: true` ile loglanır fakat background süresi active
time'a eklenmez.

## 7. Manuel oyuncu notu

Watcher terminaline şu biçimde yazıp Enter'a basın:

```text
n bulk carrier çok geç geldi
```

Not `PLAYER_NOTE` olarak o andaki tahmini active/elapsed süreyle `events.csv`ye
eklenir. Logger lifecycle kayıtları sayesinde active süre background'da ilerlemez.

## 8. Session'ı bitirme

Oyunu normal şekilde kapatın veya background'a alın. Watcher terminalinde
`Ctrl+C` kullanın. Watcher kapanırken `summary.md` dosyasını son kez yeniler.

Watcher yanlışlıkla yeniden başlatılırsa aynı Godot `run_id` için mevcut klasörü
bulur ve append eder. Logcat buffer'dan tekrar gelen satırlar kalıcı `event_id`
ile atlanır; CSV satırları çoğalmaz.

## 9. Sonuçlar

Her fresh run repository altındaki ayrı timestamp klasörüne yazılır:

```text
playtests/2026-09-11_18-30-00/
├── milestones.csv
├── events.csv
├── ship_upgrades.csv
├── port_upgrades.csv
├── summary.md
└── .playtest_session.json
```

`.playtest_session.json` yalnız watcher'ın bir `run_id`yi aynı klasörle yeniden
eşleştirmesi içindir. `playtests/` git tarafından ignore edilir.

Milestone CSV ayrıca `ship_upgrade_details` ve `port_details` JSON alanlarını
tutar. Böylece compact özetin yanında her asset'in id, ad, level, effective
değer ve koşu içi yatırım toplamları kaybolmaz.

## Sorun giderme

- **ADB bulunamadı:** `--adb C:\...\platform-tools\adb.exe` kullanın.
- **Cihaz unauthorized:** USB debugging onayını telefonda kabul edin.
- **Birden fazla cihaz:** `--serial SERIAL` kullanın.
- **Kayıt gelmiyor:** APK'nın debug export olduğundan ve oyunda yeni bir run
  başlatıldığından emin olun. Release APK bilerek hiçbir `PH_PLAYTEST` kaydı
  üretmez.
- **Logger'ı geçici kapatma:** debug çalıştırma argümanına
  `--disable-playtest-logger` ekleyin.
