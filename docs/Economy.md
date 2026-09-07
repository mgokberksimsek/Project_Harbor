# Project Harbor — Ekonomi Ölçüm Günlüğü

Bu belge geçici denge ölçümlerini ve bunlardan çıkan kararları kaydeder. Kalıcı
oyuncu kuralları için [`GDD.md`](GDD.md) esas alınır. Ölçümler
`tools/economy_balance_audit.mjs` ile mevcut `.tres` verilerinden ve çalışan
ekonomi formüllerinden yeniden üretilebilir.

## 7 Eylül 2026 — Erken ve orta oyun temel ölçümü

### Kapsam ve yöntem

- Mevcut 12 liman, üç gemi modeli, beş kargo ve 23 doğrudan deniz koridoru
  ölçüldü.
- Her açılma aşamasında yerel yük alımlı bütün geçerli liman çifti, uyumlu
  kargo, gemi ve temel kapasite miktarı kombinasyonları tarandı.
- Sonuçlar sefer masrafını içerir. Limanlar Seviye 1, gemiler geliştirmesizdir.
- Min/medyan/maks değerler teklif rastgeleliğini veya oyuncunun üç tekliften
  seçimini simüle etmez; formüllerin üretebildiği alanı gösterir.
- Liman geri dönüş hesabı tek, sürekli görev yapan Başlangıç Yük Gemisini
  kullanır. Çok gemili filoda gelir etkisi gemi sayısıyla büyür; Company Value
  ve ek yuva değeri bu nakit geri dönüş hesabına dahil değildir.

### Aşama sonuçları

| Aşama | Net kazanç min/medyan/maks | Süre min/medyan/maks | Net ₺/dk min/medyan/maks |
|---|---:|---:|---:|
| Başlangıç, 2 liman | 200 / 240 / 260 | 27,9 / 27,9 / 27,9 sn | 429,6 / 515,6 / 558,5 |
| Antalya sonrası | 183 / 243 / 325 | 23,5 / 27,6 / 32,5 sn | 374,7 / 518,2 / 691,4 |
| Çanakkale sonrası | 183 / 269 / 464 | 23,5 / 30,9 / 57,3 sn | 324,0 / 485,1 / 691,4 |
| İstanbul sonrası | 169 / 287 / 464 | 17,4 / 34,9 / 57,3 sn | 324,0 / 489,8 / 908,1 |
| Samsun sonrası | 169 / 330 / 645 | 17,4 / 43,6 / 88,5 sn | 307,1 / 462,1 / 908,1 |
| Trabzon sonrası | 169 / 371 / 766 | 17,4 / 52,3 / 108,0 sn | 274,6 / 451,4 / 908,1 |
| Pire sonrası | 169 / 388 / 1.028 | 17,4 / 53,6 / 136,1 sn | 274,6 / 453,3 / 908,1 |

Uzak bölgeler açıldıkça medyan görev ödemesi `240 ₺`'den `388 ₺`'ye çıkıyor.
Medyan dakika başı kazanç aynı aralıkta `515,6`'dan `453,3`'e geriliyor; yani
uzak görev daha yüksek toplam ödeme sunarken eski kısa rotayı verimsiz kılmıyor.
İlk 90 saniye üzeri orta süreli kombinasyonlar Trabzon aşamasında görülüyor.

### Erken oyun hedefleri

| Hedef | Ölçülen en iyi / medyan / en kötü | Geçerli hedef | Sonuç |
|---|---:|---:|---|
| Antalya, `750 ₺` | 3 / 4 / 4 görev | 3–5 görev | Geçti |
| Soğutmalı ikinci gemi, `1.280 ₺` | 5 / 6 / 7 görev | 4–8 görev | Geçti |

GDD'nin başlangıç bölümündeki eski 3–4 görevlik ikinci gemi ifadesi güncel
fiyat ve otomatik testle çeliştiği için 4–8 görev olarak düzeltildi. Oynanış
fiyatı veya ödül formülü değiştirilmedi.

### Yatırım geri dönüşleri

Antalya aşamasında kesintisiz yerel görev varsayımıyla ilk gemi geliştirmeleri:

| Gemi | Hız Sv. 1 | Kapasite Sv. 1 |
|---|---:|---:|
| Başlangıç Yük Gemisi | 4,2 dk | 5,0 dk |
| Soğutmalı Yük Gemisi | 6,7 dk | 10,1 dk |

Liman Seviye 2 için tek Başlangıç Yük Gemisiyle nakit geri dönüşü:

| Liman | Tüm yerel çiftler rastgele | Yalnız limanı kullanan rotalar |
|---|---:|---:|
| Mersin | 13,4 dk | 13,4 dk |
| Antalya | 26,8 dk | 17,8 dk |
| Çanakkale | 82,6 dk | 41,3 dk |
| İstanbul | 135,7 dk | 54,3 dk |
| Samsun | 380,1 dk | 126,7 dk |
| Trabzon | 581,3 dk | 166,1 dk |
| Pire | 913,3 dk | 228,3 dk |

Geç limanların tek gemili ve tamamen rastgele görev varsayımındaki geri dönüşü
uzun görünür. Bu tek başına fiyat düşürme gerekçesi değildir: orta oyunda filo
birden fazla gemiden oluşur, oyuncu limanı kullanan teklifleri seçebilir ve
yatırım aynı zamanda Company Value ile yuva kapasitesi sağlar. Gerçek teklif
seçimi ve eş zamanlı filo simülasyonu yapılmadan liman maliyetleri değiştirilmeyecek.

### Büyük Kontrat

Aynı iki teslimatın ayrı normal görevler olarak yapılmasına kıyasla iki duraklı
Büyük Kontratın net avantajı İstanbul–Pire aşamalarında `%8,8–%9,4` aralığındadır.
Bu değer, brüt `%8` primin işletme masrafından sonra net kazançta küçükçe daha
görünür olmasının beklenen sonucudur ve ölçülü avantaj hedefini karşılar.

### Kesintisiz büyüme alt sınırı

CV başına maliyeti düşük yatırımları seçen, bütün gemileri aralıksız çalıştıran
ve oyuncu karar gecikmesini sıfır kabul eden deterministik büyüme yolu şu alt
sınırı verdi:

| Kilometre taşı | Toplam süre | Company Level | CV | Filo |
|---|---:|---:|---:|---:|
| Antalya | 1,5 dk | 2 | 1.400 | 1 |
| Soğutmalı ikinci gemi | 3,9 dk | 3 | 2.600 | 2 |
| Çanakkale | 5,3 dk | 3 | 3.400 | 2 |
| İstanbul | 9,4 dk | 4 | 6.000 | 3 |
| Samsun | 14,5 dk | 5 | 10.170 | 3 |
| İlk Dökme Yük Gemisi | 21,7 dk | 6 | 14.610 | 5 |
| Trabzon | 23,6 dk | 6 | 17.610 | 5 |
| Pire | 29,3 dk | 7 | 24.960 | 5 |
| Varna | 38,0 dk | 8 | 35.580 | 5 |

Bu sonuç normal oyuncu süresi değildir. Yerel görevlerin ortalama gelirini
kesintisiz nakit akışı sayar; uzak yük alımını, üç teklif örneklemesini,
panellerde geçen zamanı, gemi boşta kalmasını ve farklı yatırım tercihlerini
hesaba katmaz. Yine de Level 8 için `38 dk` alt sınırı, orta oyunun prototip
sürelerle sıkışma riski taşıdığını gösterir. Daha gerçekçi teklif ve olay
simülasyonu da benzer sonuç verirse önce mevcut süre, ödül ve yatırım değerleri
ayarlanacaktır; yeni ekonomi sistemi eklenmeyecektir.

### Karar ve sonraki ölçüm

Bu temel taramada ekonomi verisi veya formül değişikliği gerektiren ölçülmüş bir
sorun bulunmadı. Kesintisiz büyüme alt sınırı ise orta oyunun fazla hızlı olma
riskini ortaya çıkardı, fakat iyimser varsayımları nedeniyle tek başına veri
değişikliğini haklı çıkarmıyor. Sonraki denge adımı üç gerçek teklif örneklemesi,
uzak yük alımı, eş zamanlı görev bitişleri ve oyuncu karar gecikmesini içeren
çoklu koşuyla Company Level 6–8 zaman dağılımını ölçmektir. Nihai süre kararı
ayrıca Android cihaz oturumuyla doğrulanmalıdır.

## 7 Eylül 2026 — Android oyuncu oturumu

Oyuncunun bağlı telefondaki mevcut kayıttan bildirdiği başlangıç durumu:

| Değer | Ölçüm |
|---|---:|
| Cash | 6.327 ₺ |
| Company Value | 12.020 CV |
| Level 6 eksiği | 980 CV |
| Filo | 4 gemi: Orion, Nautica, Yakamoz, Mercan |
| Açık limanlar | Mersin, İzmir, Antalya, Çanakkale, İstanbul, Samsun |
| Tamamlanan görev | 97 |
| Büyük Kontrat | 18 |
| Otomasyon | Nautica'da açık fakat kapalı durumda |

Bu noktadan yaklaşık 5 dakika sonra Level 6'ya ulaşıldı ve beşinci gemi alındı.
Takip eden yaklaşık 10 dakikada Level 7'ye ulaşıldı, iki gemi için daha
otomasyon açıldı, Trabzon açıldı ve gemi/liman geliştirmeleri satın alındı.
Oyuncu mesajında Samsun'un da bu sonraki bölümde açıldığı belirtildi; başlangıç
tablosunda Samsun zaten açık göründüğü için bu ayrıntı sonraki cihaz kaydıyla
tekrar doğrulanmalıdır.

Başlangıç Cash'i düşüldüğünde, yalnızca iki yeni otomasyon (`10.000 ₺`), en
ucuz olası beşinci gemi (`3.280 ₺`) ve Trabzon (`6.500 ₺`) bile 15 dakikada en
az `13.453 ₺` yeni gelir gerektirir. Bu, bildirilen gemi/liman geliştirmeleri
hariç filo genelinde en az yaklaşık `897 ₺/dk` gerçek nakit üretimidir. Alınan
gemi daha pahalı bir modelse gerçek alt sınır daha yüksektir.

Bu cihaz gözlemi, deterministik ölçümde görülen orta oyun sıkışma riskini
doğrular. Level 6'dan Level 7'ye yatırım ve otomasyon harcamalarına rağmen
yaklaşık 10 dakikada geçilebilmesi, paralel filo gelirinin mevcut orta oyun
maliyetlerinden hızlı büyüdüğünü gösterir. Yine de hangi değerin değişeceği,
Level 6–7 için hedeflenen oyuncu süresi belirlendikten ve cihaz kaydındaki gemi
modelleri ile yatırım seviyeleri doğrulandıktan sonra seçilmelidir.
