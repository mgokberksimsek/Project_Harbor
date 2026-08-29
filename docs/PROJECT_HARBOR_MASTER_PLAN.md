# Project Harbor — Ana Proje Özeti ve Geliştirme Planı

> Son güncelleme: 29 Ağustos 2026  
> Proje durumu: Oynanabilir Android prototipi  
> Motor: Godot 4.7.1  
> Öncelikli platform: Android, yatay mobil  
> Tür: 2D filo ve liman yönetimi / tycoon  
> Oyun modu: Tek oyunculu

Bu dosya Project Harbor için bugüne kadar yapılanları, alınan temel tasarım
kararlarını, prototip değerlerini ve gelecekte değerlendireceğimiz özellikleri
tek yerde toplar. Ayrıntılı ve kesinleşmiş oyuncu kuralları için
[`GDD.md`](GDD.md), kodun nasıl düzenlendiği için
[`ARCHITECTURE.md`](ARCHITECTURE.md), geliştirme ilkeleri için repository
kökündeki [`AGENTS.md`](../AGENTS.md) esas alınır.

Bu belgedeki durum etiketleri:

- **Çalışıyor:** Oyunda uygulanmış ve kullanılabilir.
- **Prototip:** Çalışıyor; değerleri, görünümü veya kullanıcı deneyimi nihai değil.
- **Sırada:** Yakın geliştirme döneminde ele alınması öneriliyor.
- **Planlandı:** Tasarım yönü uygun, ancak zamanı ve ayrıntıları kesinleşmedi.
- **Askıda:** Bilinçli olarak şimdilik yapılmıyor.
- **Kapsam dışı:** Project Harbor'ın hedef deneyimine uygun bulunmadı.

---

## 1. Projenin özü

Project Harbor'ın temel fantezisi gemiyi elle sürmek değil, küçük bir deniz
taşımacılığı işletmesini büyütmektir.

Oyuncunun yolculuğu şu ölçekte hissedilmelidir:

```text
0 gemi + 2 açık liman
↓
İlk gemi + kısa görevler
↓
Birden fazla gemi + yeni bölgeler + uzmanlaşma
↓
Geliştirilmiş limanlar + otomatik çalışan gemiler + büyük kontratlar
↓
12 limanlık, çok gemili ve çok bölgeli lojistik şirketi
```

Yeni bir özellik şu üç değerden en az birini güçlendirmelidir:

1. Filo büyümesi ve gemiler arasında anlamlı seçim.
2. Liman ağının genişlemesi ve haritanın daha verimli kullanılması.
3. Oyuncunun şirketini büyüttüğünü hissettiren açık yatırım kararları.

Gerçekçilik tek başına yeterli gerekçe değildir. Aynı oyuncu değerini daha az
menü, daha az kural ve daha az beklemeyle sağlayan çözüm tercih edilir.

---

## 2. Güncel oyun başlangıcı

**Durum: Çalışıyor / prototip denge**

- Oyuncu sıfır gemiyle başlar.
- Başlangıç parası `500 ₺`'dir.
- Bu para ilk Başlangıç Yük Gemisini almaya tam yeter.
- Mersin ve İzmir açık başlar.
- İlk genişleme hedefi Antalya'dır.
- Satın alınan ilk gemi şirket merkezinde belirir.
- Oyuncu ilk görevi öğretici eşliğinde kabul eder.
- İlk görevler kısa tutulur; oyuncu uygulama açıkken sık karar verir.
- İlerleyen limanlar ve kontratlar daha uzun süreli oynanışa geçiş sağlar.

Erken oyun hedefi, oyuncuyu birkaç dakika içinde şu döngüyle tanıştırmaktır:

```text
Gemi satın al
↓
Gemiyi seç
↓
Görev işaretli limanı seç
↓
Üç tekliften birini kabul et
↓
Yükleme ve teslimatı izle
↓
Net kazancı al
↓
Yeni liman, gemi veya geliştirmeye yatırım yap
```

---

## 3. Bugüne kadar tamamlanan oyuncu özellikleri

### 3.1 Başlangıç öğreticisi

**Durum: Çalışıyor; görsel sunum ileride geliştirilecek**

Sekiz adımlı öğretici oyuncuya sırayla şunları yaptırır:

1. Gemi mağazası sekmesini açma.
2. İlk gemiyi satın alma.
3. Company Value göstergesinden Şirket İlerlemesi panelini açma.
4. `?` düğmesine dokunup Company Value açıklamasını onaylama.
5. Şirket merkezindeki gemiyi seçme.
6. Görev işaretli limanı seçme.
7. İlk görev teklifini kabul etme.
8. “Hazırsın Kaptan!” kapanışını onaylama.

Her adım tamamlanmadan sonraki ana etkileşim kullanılamaz. İlgili buton veya
nesne hafif bir nabız efektiyle vurgulanır. Oyuncu isterse öğreticiyi atlayabilir;
bu seçim de olumlu bir “Hazırsın Kaptan!” penceresiyle onaylanır. Öğreticinin
tamamlanma veya atlanma bilgisi kaydedilir.

Öğretici sonrasında tek satırlık “Sonraki Hedef” alanı ilk liman, ikinci gemi
ve bölgesel genişleme hedeflerini veri odaklı biçimde gösterir.

### 3.2 Gemi seçimi ve görev verme

**Durum: Çalışıyor**

- Gemiye doğrudan dokunarak veya filo panelinden seçerek görev hazırlanabilir.
- Filo panelinden seçim kamerayı yumuşakça gemiye götürür.
- Seçili gemi kendi siluetini izleyen vurguyla ve `%5` büyümeyle belirtilir.
- Seçili geminin taşıyabildiği kargolara uygun limanlarda küçük görev işaretleri
  görünür.
- İşarete dokunulduğunda aynı anda üç görev teklifi gösterilir.
- Aynı görevin kopyaları üç ayrı kart olarak gösterilmez.
- Teklif kabul edilince gemi kendiliğinden yükleme ve teslimat rotasını izler.
- Aynı anda birden fazla gemiye bağımsız görev verilebilir.
- Haritanın boş bir alanına gerçek dokunuş açık panelleri ve seçimleri kapatır.
- Haritayı sürüklemek veya yakınlaştırmak seçimi yanlışlıkla sıfırlamaz.

### 3.3 Görev üretimi

**Durum: Çalışıyor**

- Görev teklifleri rastgele üretilir.
- Teklifler seçili geminin kargo yeteneklerine göre filtrelenir.
- Yükleme ve teslimat limanı aynı olamaz.
- Gemi yalnızca bulunduğu limandan yük almak zorunda değildir.
- Örneğin İzmir'deki gemi Mersin'den yük alıp İstanbul'a teslim edebilir.
- Doğrudan rota bulunmasa bile açık deniz ağıyla bağlı tüm liman çiftleri
  arasında görev oluşabilir.
- Kilitli limanlar normal görev havuzuna girmez.
- Teslimat yuvası olmayan dolu limanlara yeni görev üretilmez.
- Görev kartında rota, kargo, miktar, tahmini süre, brüt ödeme, sefer masrafı
  ve net kazanç gösterilir.

### 3.4 Büyük Kontratlar

**Durum: Çalışan ilk sürüm**

- Büyük Kontratlar Company Level 4'te görünmeye başlar.
- İlk sürüm tek kabulde birbirine bağlı iki teslimat içerir.
- Gemi ilk teslimattan sonra yeni yükü alıp oyuncudan tekrar komut beklemeden
  ikinci teslimata geçer.
- Brüt ödül iki teslimat toplamına `%8` kontrat primi eklenerek hesaplanır.
- İşletme masrafları iki teslimat için birlikte hesaplanır.
- Ödeme yalnızca bütün kontrat tamamlandığında yapılır.
- Başlamış kontrat, oyun kapalıyken zaman bazlı olarak ilerler.
- İlk kabulde bu davranış tek seferlik kısa bir bilgi mesajıyla açıklanır.
- Tam rota, sözleşmenin bütün ayaklarıyla birlikte baştan gösterilir.

İleri sürümde daha uzun ve daha fazla duraklı kontratlar değerlendirilebilir;
ancak mevcut iki teslimatlı sürüm dengelenmeden yeni kontrat kuralları
eklenmeyecektir.

### 3.5 Gemi hareketi ve liman davranışı

**Durum: Çalışıyor; nihai görseller daha sonra gelecek**

Gemi durumları:

```text
Boşta
→ Yük Limanına Gidiyor
→ Yükleniyor
→ Teslimata Gidiyor
→ Boşaltıyor
→ Boşta
```

- Başka limandan yük alacak gemi mevcut limanın merkezine gereksiz yere uğramaz.
- Bulunduğu limandan yük alacak gemi liman merkezine doğru gerçek bir yaklaşım
  rotası izler ve yükleme orada yapılır.
- Yük alma sırasında kalıcı bir liman yuvasına oturmaz.
- Yüklemeden sonra yuvaya dönmeden teslimat rotasına devam eder.
- Boşaltma liman merkezinde görünür bir beklemeyle gerçekleşir.
- Boşaltma tamamlandıktan sonra gemi ayrılmış boş yuvaya yumuşakça yanaşır.
- Liman giriş hızı uzun görev süresinden etkilenmez; yaklaşma her zaman kısa ve
  okunabilir bir görsel sürede tamamlanır.
- Gemi burnu rota teğetine hizalanır.
- Yuvadan çıkışlar ve liman dönüşleri ani açı sıçramaları olmadan yumuşatılmıştır.
- Kayıttan yüklenen aktif gemi, geçen süreye uygun rota noktasında görünür;
  başlangıca veya sona ışınlanmış hissi azaltılmıştır.

### 3.6 Kırmızı deniz rotaları

**Durum: Çalışıyor**

- Rotalar kırmızı ve kesikli çizgiyle gösterilir.
- Çizgiler düz bağlantılar yerine geniş kavisler ve kontrollü S-kıvrımları
  kullanır.
- Görevin yük alma ve teslimat ayakları aynı anda görünür.
- Gemi ilerledikçe yalnızca geçilmiş çizgi parçaları kaybolur.
- İlerideki rota gemiye doğru kaymaz veya erken kısalmaz.
- Gidiş ve dönüş aynı koridoru kullanıyorsa kesikler üst üste binerek düz çizgiye
  dönüşmez.
- Aynı koridorun gelecekteki dönüş bölümü, ilk geçiş bitmeden yanlışlıkla öne
  çıkmaz; geçilmiş bölüm geminin arkasında iz gibi kalmaz.
- Birleşik rotalar bağlantı limanlarının merkezine uğramaz; açık deniz geçiş
  noktalarını kullanır.
- Rotalar kara poligonlarının içinden geçmemeleri için otomatik test edilir.

### 3.7 Limanlar ve yanaşma yuvaları

**Durum: Çalışıyor**

- Kilitli limana dokunmak doğrudan para harcamaz; önce bilgi ve onay paneli açar.
- Panel maliyeti, gereken Company Level'ı, mevcut parayı ve kazanılacak Company
  Value'yu gösterir.
- Koşullar eksikse satın alma düğmesi nedeni belirterek devre dışı kalır.
- Seçili liman kendi şekline uygun vurguyla ve `%5` büyümeyle belirtilir.
- Birden fazla gemi aynı limanda üst üste binmez.
- Gelen gemi ilk boş yuvaya yerleşir.
- Ön sıradaki yuva boşalınca en sondaki gemi yumuşakça öne geçer.
- Görev kabul edildiğinde teslimat yuvası önceden ayrılır.
- Liman seviyeleri bekleyebilecek gemi sayısını artırır.

### 3.8 Liman geliştirmeleri

**Durum: Çalışan üç seviyeli prototip**

| Liman seviyesi | Görev geliri etkisi | Yükleme/boşaltma süresi | Gemi yuvası |
|---:|---:|---:|---:|
| 1 | Temel | 3,0 sn | 2 |
| 2 | `%8` artış | 2,4 sn | 4 |
| 3 | `%16` artış | 1,8 sn | 6 |

Liman geliştirmek Cash harcar ve sabit Company Value sağlar. Görev ödülünde
iki limanın geliştirme çarpanları ortalanıp yalnızca bir kez uygulanır; böylece
ekonomi katlanarak şişmez. Seçili gemi yokken açık limana dokunmak geliştirme
işlemini açar; rutin görev verme akışına yeni menü eklenmez.

### 3.9 Gemi satın alma ve filo fiyatları

**Durum: Çalışıyor; fiyatlar prototip dengedir**

- Üç veri odaklı ana gemi sınıfı bulunur.
- Herhangi bir sınıftan gemi almak bütün gemi modellerinin fiyatını artırır.
- Güncel formül: `Taban fiyat × 1,6 ^ sahip olunan toplam gemi sayısı`.
- Sonuç en yakın `10 ₺`'ye yuvarlanır.
- Böylece oyuncu farklı sınıfları sırayla alarak fiyat artışını atlayamaz.
- Satın alma için yeterli Cash ve geminin gerekli Company Level'ı gerekir.
- Filo kapasitesi de Company Level ile sınırlandırılır.
- Yeni alınan gemi şirket merkezinin açık deniz tarafında belirir ve merkezin
  yuvasına yumuşakça yerleşir.

Güncel gemi prototipleri:

| Gemi | Temel fiyat | Gerekli seviye | Temel kapasite | Kargo rolü |
|---|---:|---:|---:|---|
| Başlangıç Yük Gemisi | `500 ₺` | 1 | 1 | Genel |
| Soğutmalı Yük Gemisi | `800 ₺` | 2 | 2 | Genel + soğutmalı |
| Dökme Yük Gemisi | `1.500 ₺` | 3 | 3 | Dökme yük |

### 3.10 Gemi geliştirmeleri

**Durum: Çalışıyor; denge değerleri ayarlanacak**

- Hız en fazla 5 seviye geliştirilebilir.
- Her hız seviyesi temel hıza `%15` ekler.
- Hız geliştirme fiyatı seviye başına `1,7` katsayısıyla büyür.
- Kapasite en fazla 3 seviye geliştirilebilir.
- Kapasite geliştirme fiyatı seviye başına `1,8` katsayısıyla büyür.
- Görevde kullanılan her ek kargo birimi brüt ödülü `%25` artırır.
- Boş gemi nominal hızdan `%10` hızlı gider.
- Yüklü gemi her kargo birimi için `%5` yavaşlar; toplam ceza `%20` ile sınırlıdır.
- Geliştirmeler satın alındığı anda uygulanır.
- Gemi geliştirmek için tersaneye veya şirket merkezine dönmek gerekmez.
- Sonsuz hızlandırma veya sonsuz kapasite artışı yoktur.

### 3.11 Gemi isimleri

**Durum: Çalışıyor**

- Yeni gemiler filoda kullanılmayan rastgele denizcilik/keşif isimleri alır.
- Oyuncu gemi adını ücretsiz değiştirebilir.
- İsim paneli iki satırlık kompakt mobil düzendedir.
- İlk satırda metin alanı ile aynı yükseklikte zar düğmesi bulunur.
- Zar düğmesi yeni ve kullanılmayan rastgele isim önerir.
- İkinci satırda Kaydet ve Vazgeç eylemleri bulunur.
- Panel ekranın üst tarafında açılarak Android klavyesinin içeriği kapatması
  azaltılır.
- İsimler 2–20 karakterdir ve aynı filoda tekrarlanamaz.
- Yeni isim gemi etiketi, filo listesi ve ayrıntı panelinde birlikte güncellenir.
- İsimler kayıt dosyasında saklanır; eski kayıtlar güvenli biçimde adlandırılır.

### 3.12 Filo paneli ve yönetim çubuğu

**Durum: Çalışıyor; büyük filo iyileştirmeleri planlı**

- Filo ve Gemi Satın Alma, ekranın altında birleşik yönetim çubuğunun iki
  bağımsız sekmesidir.
- İki sekme aynı anda açılabilir.
- Birlikte açıkken filo alanına daha fazla yer verilir.
- Harita dokunuşu açık sekmeleri kapatır; sürükleme ve yakınlaştırma kapatmaz.
- Filo panelinin sol tarafı kaydırılabilir gemi listesidir.
- Sağ taraf seçili geminin ayrıntı, geliştirme ve otomasyon işlemlerini gösterir.
- Tamamlanan görev sayısı ve geminin kazandırdığı toplam net para gösterilir.
- Filo panelindeki `?` düğmesi panelin kullanımını kısa şekilde açıklar.
- Filo listesinin dokunmatik kaydırması Android için düzeltilmiştir.

### 3.13 Boşta gemi geri bildirimi

**Durum: Çalışıyor**

- Boşta olan gemide sabit duran durum yazısı bulunur.
- Yazı sağa sola hareket etmeden hafif ve hızlı bir renk nefesiyle dikkat çeker.
- Görev başlayınca efekt durur.
- “Boşta / Idle” metni seçilen dile göre güncellenir.

### 3.14 Otomatik görev

**Durum: Çalışan çevrimiçi ilk sürüm**

Otomatik görev filo genelinde değil, gemi başına açılır.

Güncel şartlar:

- Company Level 5.
- İlgili gemiyle tamamlanmış 2 Büyük Kontrat.
- Tek seferlik `5.000 ₺` yatırım.

Otomasyon açıldıktan sonra ücretsiz açılıp kapatılabilir. Oyun açıkken boşta
kalan gemi, net kazancı pozitif teklifler arasından tahmini süre başına en iyi
net kazancı seçer. Otomasyon kapatılırsa mevcut görev bitirilir ancak yeni görev
alınmaz.

Oyun kapalıyken yeni görev zinciri üretmek **şimdilik askıdadır**. Yalnızca
uygulama kapanmadan önce başlamış görev veya kontrat ilerler.

### 3.15 Company Value ve Company Level

**Durum: Çalışıyor; uzun dönem eşikleri prototip**

Üç kavram birbirinden ayrıdır:

- **Cash:** Harcanabilir para.
- **Company Value:** Oyuncunun sahip olduğu kalıcı şirket varlıklarının değeri.
- **Company Level:** Ulaşılan en yüksek Company Value'ya bağlı kalıcı seviye.

Güncel sade formül:

```text
Company Value
= gemilerin varlık değeri
+ gemi hız ve kapasite geliştirmeleri
+ açık limanların varlık değeri
+ liman geliştirmeleri
```

Cash doğrudan Company Value üretmez. Bu nedenle kasada para bekletmek yerine
gemiye ve limana yatırım yapmak daha değerlidir. Görev sayısı ve taşınan yük de
şimdilik doğrudan Company Value üretmez. Company Level düşmez; bir kez açılan
içerik Company Value daha sonra azalsa bile yeniden kilitlenmez.

Güncel 15 seviyelik prototip eşikleri:

| Seviye | Gerekli en yüksek CV | Filo kapasitesi |
|---:|---:|---:|
| 1 | 0 | 2 |
| 2 | 1.000 | 3 |
| 3 | 2.400 | 4 |
| 4 | 4.800 | 5 |
| 5 | 8.000 | 6 |
| 6 | 13.000 | 8 |
| 7 | 20.000 | 10 |
| 8 | 30.000 | 12 |
| 9 | 43.000 | 14 |
| 10 | 60.000 | 16 |
| 11 | 82.000 | 17 |
| 12 | 109.000 | 18 |
| 13 | 142.000 | 19 |
| 14 | 183.000 | 20 |
| 15 | 235.000 | 21 |

Company Level yeni gemileri, liman bölgelerini, filo kapasitesini ve gelecekte
uygun olduğunda yeni sistemleri açabilir. Ancak her içerik yalnızca seviyeye
bağlanmayacaktır. Özel içeriklerde en fazla `Company Level + Cash + bir tematik
koşul` kullanılacaktır.

### 3.16 Şirket merkezi

**Durum: Çalışıyor**

- Merkez denize sıfır konumlandırılmıştır.
- Başlangıç gemisi dahil satın alınan gemiler merkezde belirir.
- Gemilerin başlangıç yuvaları liman kapasitesini tüketmez.
- Merkez Company Level arttıkça dört görsel aşamada büyür:
  küçük ofis, büyümüş merkez, bölgesel merkez ve kule/gökdelen.
- İskele ve gemi yaklaşım yolu bina büyüdükçe görsele uyum sağlar.
- İskele çatı içinden çıkmaz; açık deniz tarafına bağlı görünür.
- Merkezin büyümesi otomatik ve görseldir; ayrıca satın alma veya menü istemez.
- Gemi geliştirmek için merkeze dönme zorunluluğu yoktur.

### 3.17 Görev ekonomisi ve sefer masrafı

**Durum: Çalışıyor; nihai denge yapılmadı**

Brüt görev ödülü şunlardan oluşur:

- Kargonun temel değeri.
- Yükleme ile teslimat arasındaki oynanış mesafesi.
- Kargo miktarı.
- İki limanın ekonomik kademesinin ortalaması.
- İki limanın geliştirme çarpanının ortalaması.

Liman ekonomik kademe çarpanları `x1,00`, `x1,08`, `x1,16` ve `x1,25`'tir.
İki limanın çarpanları ayrı ayrı katlanmak yerine ortalanır.

Sefer masrafı:

- Geminin başka limana boş gitme mesafesini,
- Yüklü teslimat mesafesini,
- Gemi sınıfının tüketim oranını,
- Prototip yakıt birim fiyatını

birlikte kullanır. Masraf görev kabulünde kasadan düşmez; teslimatta brüt
ödülden çıkarılır. Böylece oyuncu yakıt parası kalmadığı için tamamen
kilitlenmez. Kartta ve teslimat özetinde brüt gelir, masraf ve net kazanç açıkça
gösterilir.

Ayrı yakıt tankı, manuel yakıt satın alma, maaş ve düzenli kira sistemi henüz
uygulanmamıştır.

### 3.18 Kayıt ve çevrimdışı ilerleme

**Durum: Çalışıyor**

- Oyun verisi sürüm numaralı JSON dosyasında tutulur.
- Cash, gemiler, isimler, geliştirmeler, limanlar, Company Level, aktif görevler,
  otomasyon durumu ve öğretici ilerlemesi kaydedilir.
- Otomatik kayıt aralığı prototipte 10 saniyedir.
- Zaman bazlı işlemler başlangıç zamanı, süre ve durumla saklanır.
- Uygulama kapalıyken daha önce başlamış görevler ilerler.
- Oyun açıldığında tamamlanan görevler ve gemi konumları geçen zamana göre
  yeniden kurulur.
- En az bir görev çevrimdışıyken tamamlandıysa “Sen yokken...” özeti tamamlanan
  sefer sayısını ve toplam kazancı gösterir.
- Ayarlardan onay vererek kayıt silinebilir ve temiz oyun başlatılabilir.
- Dil ve ses tercihleri oyun kaydından ayrı tutulduğu için yeni oyunda korunur.
- Eski kayıtlar için güvenli varsayımlar ve veri uyumluluğu kontrolleri bulunur.

### 3.19 Harita ve kamera

**Durum: Çalışıyor**

- Harita parmakla sürüklenebilir ve bırakıldığında kontrollü ataletle devam eder.
- Dokunurken harita parmağın önüne kaçmaz; hareket bire bir ve okunabilirdir.
- Çift dokunma genel görünüm ile yakın görünüm arasında yumuşak geçiş yapar.
- Normal oynanışta geniş bir uzaklaştırma sınırı vardır.
- Bu sınırın ötesine devam edildiğinde tüm haritayı ortalayan sinematik görünüm
  açılır.
- Sinematik görünümde sürükleme devre dışıdır.
- Yakınlaştırmak oyuncuyu önce normal en uzak sınıra geri getirir.
- Filo panelindeki gemiye dokunmak mevcut zoom seviyesini koruyarak kamerayı
  gemiye odaklar.
- Kamera mobil yatay görünüm ve dokunmatik hareket için ayarlanmıştır.
- Telefon 180 derece çevrildiğinde yatay yön cihaz sensörüne göre değişebilir.

### 3.20 Yönetim panelleri ve mobil etkileşim

**Durum: Çalışıyor; görsel tasarım prototip**

- Rutin görev verme birkaç dokunuşla tamamlanır.
- Kritik paneller haritayı mümkün olduğunca az kaplar.
- Görev teklif paneli alt yönetim çubuğuyla üst üste binmez.
- Ayarlar, filo ve şirket ilerleme panellerinin açılma/kapanma davranışları
  dokunmatik sürüklemeden ayrılmıştır.
- Mobil dokunma alanları küçük görsel ikonlardan daha geniş tutulur.
- Gemi ve liman seçimi doğrudan harita üzerinden yapılabilir.
- Paneller açıldığında oyun zamanı durmaz; görevler arkada ilerlemeye devam eder.

### 3.21 Ayarlar, dil ve çıkış

**Durum: Çalışıyor; gerçek ses varlıkları henüz yok**

- Ayarlar menüsünden oyuna devam edilebilir.
- Ses efektleri ve müzik ayrı ayrı açılıp kapatılabilir.
- Türkçe ve İngilizce oyun sırasında değiştirilebilir.
- Yeni oyun başlatma onay gerektirir.
- Android geri tuşu eğlenceli bir çıkış onayı açar.
- Ayarlar veya çıkış onayı açıkken görev süreleri durmaz.
- Dil ve ses tercihleri ayrı cihaz ayarında saklanır.

### 3.22 Android prototipi

**Durum: Çalışıyor**

- Android debug export ayarı hazırdır.
- Paket kimliği `com.gokberksimsek.projectharbor`'dır.
- Güncel prototip sürüm adı `0.1.0`'dır.
- ARMv7 ve ARM64 APK üretilebilir.
- Oyun yatay, tam ekran ve mobil öncelikli çalışır.
- APK gerçek Android telefona kurulup dokunma, kaydırma, görev, kontrat,
  çevrimdışı ilerleme ve arayüz davranışları test edilmiştir.
- Terminalden headless export ve ADB ile güncelleme/kurulum yapılabilir.

### 3.23 Geçici geliştirme araçları

**Durum: Prototip; yayın sürümünde kaldırılmalı veya güvenli biçimde gizlenmeli**

- Bir Company Level yükselten test düğmesi.
- `10.000 ₺` ekleyen test düğmesi.
- Hızlı görev süreleri ve prototip ekonomi değerleri.
- Kapsamlı headless smoke testi.

Bu araçlar geliştirme hızını artırır; oyuncuya gönderilecek üretim sürümünün
kalıcı parçası değildir.

---

## 4. Güncel içerik kapsamı

### 4.1 Limanlar

**12 limanlık ilk bölgesel ağ tamamlandı.**

| Liman | Durum / sıra | Açma maliyeti / CV katkısı |
|---|---|---:|
| Mersin | Başlangıçta açık | — |
| İzmir | Başlangıçta açık | — |
| Antalya | İlk genişleme, Sv. 1 | `750 ₺`, `500 CV` |
| Çanakkale | Sv. 3 | `1.500 ₺`, `800 CV` |
| İstanbul | Sv. 4 | `2.600 ₺`, `1.200 CV` |
| Samsun | Sv. 5 | `4.200 ₺`, `2.000 CV` |
| Trabzon | Sv. 6 | `6.500 ₺`, `3.000 CV` |
| Pire | Sv. 7 | `8.500 ₺`, `4.200 CV` |
| Varna | Sv. 8 | `11.000 ₺`, `5.500 CV` |
| Batum | Sv. 9 | `14.500 ₺`, `7.200 CV` |
| Girne | Sv. 10 | `19.000 ₺`, `9.000 CV` |
| İskenderiye | Sv. 11 | `25.000 ₺`, `11.500 CV` |

Bu maliyetler ve CV değerleri nihai ekonomi değildir. On iki limanın dengesi
tamamlanmadan yeni liman sayısını artırmak öncelikli değildir. Gelecekte yeni
bölge gerekirse yabancı liman isimleriyle ölçek hissi büyütülebilir.

### 4.2 Deniz ağı

- 23 veri odaklı doğrudan deniz koridoru bulunur.
- Bu koridorlar ara bağlantılarla tüm açık liman çiftleri arasında görev
  kurulmasını sağlar.
- Rota seçimi gereksiz liman merkezlerine uğramadan en uygun ağ yolunu kullanır.
- Gidiş-dönüş ortak koridorları ve kesikli çizgi önizlemesi düzenlenmiştir.
- Kara içinden geçme, aşırı zikzak ve gereksiz geri izleme smoke testleriyle
  denetlenir.

### 4.3 Kargolar

Mevcut prototip kargoları:

- Konteyner.
- Metal.
- Makine parçaları.
- Gıda.
- Tahıl.

Kargolar genel, soğutmalı veya dökme yük yetenekleriyle gemilere bağlanır.
Yeni kargo eklemek veri dosyası üzerinden yapılabilir.

### 4.4 Gemi sınıfları

- Başlangıç Yük Gemisi.
- Soğutmalı Yük Gemisi.
- Dökme Yük Gemisi.

Yeni sınıflar ancak yeni bir görev seçimi veya uzmanlaşma değeri yaratıyorsa
eklenecektir; yalnızca istatistik farkı olan çok sayıda gemi hedeflenmez.

---

## 5. Teknik temel

### 5.1 Veri ve çalışma zamanı ayrımı

- Limanlar, gemi modelleri, kargolar ve deniz rotaları `.tres` verileridir.
- Oyuncunun anlık gemileri, görevleri ve liman seviyeleri çalışma zamanı
  durumudur.
- Kayıt verisine `Node` veya `Resource` referansı yazılmaz; kararlı kimlikler
  kullanılır.
- Oyun kaydı JSON'dur; tasarım verileriyle karıştırılmaz.
- Yeni içerik mümkün olduğunca yeni veri kaynağı eklenerek oluşturulur.

### 5.2 Mevcut sistem sahipliği

| Sistem | Sorumluluk |
|---|---|
| `GameManager` | Cash, öğretici ve oturum akışı |
| `PortManager` | Liman kayıtları, kilitler ve seviyeler |
| `FleetManager` | Oyuncu gemileri, durum makinesi ve görev ataması |
| `MissionManager` | Teklif ve görev yaşam döngüsü |
| `EconomyManager` | Ödül, masraf, fiyat ve geliştirme formülleri |
| `CompanyManager` | Company Value, en yüksek değer ve Company Level |
| `SettingsManager` | Dil ile efekt/müzik tercihleri |
| `SaveManager` | Sürümlü JSON kayıt ve geri yükleme |
| `EventBus` | Sistemlerin gözlemlemesi gereken önemli olaylar |

Yeni bir özellik için otomatik olarak yeni manager oluşturulmaz. Davranış,
veriye zaten sahip olan mevcut sisteme eklenir. Sinyaller yalnızca birden fazla
sistemin gerçekten bilmesi gereken olaylarda kullanılır.

### 5.3 Zaman modeli

Görev hareketi kare kare birikmiş zamana bağımlı değildir. Her ayak için
başlangıç zamanı, süre ve durum saklanır. Görsel gemi konumu bu veriden
hesaplanır. Bu temel hem uygulama kapalıyken ilerlemeyi hem de kayıt sonrası
doğru konuma dönmeyi sağlar.

### 5.4 Test yaklaşımı

Mevcut smoke testi başlıca şunları korur:

- Para ekleme/harcama ve sefer masrafı.
- Liman açma ve yükseltme.
- Gemi satın alma, fiyat artışı ve filo kapasitesi.
- Company Value / Company Level ilerlemesi.
- Görev teklifleri, kabul, tamamlama ve ödül.
- Büyük Kontrat ve otomasyon gereksinimleri.
- Kayıt/yükleme ve çevrimdışı ilerleme.
- Liman yuvaları ve gemi durumları.
- Kamera, öğretici ve panel yerleşimi.
- Rotaların kara üzerinden geçmemesi, düzgün birleşmesi ve ilerledikçe silinmesi.
- Bütün liman çiftlerinde ekonomi ve süre sonuçlarının geçerli olması.

Görsel veya dokunmatik değişiklikler yalnızca headless testle tamamlanmış
sayılmaz; bağlı Android telefonda da kontrol edilir.

---

## 6. Bundan sonra önerilen geliştirme sırası

Bu sıra, oyuna aynı anda çok fazla sistem eklememek ve önce temel ekonomi
döngüsünü güvenilir hale getirmek için önerilir.

### Aşama 1 — Mevcut 12 limanlık oyunu dengele

**Durum: Sırada / en yüksek öncelik**

1. Gerçek cihazda erken, orta ve geç oyun görev sürelerini ölç.
2. İlk liman, ikinci gemi ve ilk uzman gemiye ulaşma sürelerini ölç.
3. Uzak limanların daha yüksek toplam kazanç sağladığını ancak kısa rotaları
   tamamen anlamsızlaştırmadığını doğrula.
4. Gemi geliştirmelerinin maliyetini geri kazanma süresini ölç.
5. Liman seviye 2 ve 3 yatırımlarının gelir ile süre etkisini ölç.
6. Büyük Kontratın normal iki göreve göre anlaşılır ve dengeli avantajını test et.
7. Level 15'e normal oynanışla ulaşılabilirliği ve 20–30 saatlik hedef eğrisini
   simüle et.
8. Nihai olmayan test düğmelerini üretim dışı bırakacak yolu belirle.

Bu aşamada yeni para türü, pazar sistemi veya yeni liman eklemek önerilmez.

### Aşama 2 — Oyuncuya mevcut sistemleri daha iyi öğret

**Durum: Sırada**

- İlk gemi geliştirmesinde hız ve kapasitenin etkisini kısa bağlamsal metinle
  anlat.
- İlk orta/uzun görevde oyunun kapalıyken ilerlediğini açıkla.
- Otomatik görev açılabilir hale geldiğinde şartları ve yalnızca oyun açıkken
  yeni görev seçtiğini anlat.
- Company Value, filo ve ilgili panellerdeki `?` açıklamalarını aynı kısa görsel
  dilde tut.
- Öğreticiyi nihai ikon, animasyon ve ses yönü belirlendiğinde görsel olarak
  güçlendir; yeni zorunlu adımlarla uzatma.

### Aşama 3 — Büyük filo kullanılabilirliği

**Durum: Planlandı**

10 ve üzeri gemiyle gerçek mobil test yapıldıktan sonra gerekirse:

- Boşta / görevde / otomatik gemi filtreleri.
- Kargo uzmanlığına göre filtre.
- Durum grupları veya daha kompakt kartlar.
- Haritada yoğun gemi trafiğinin okunabilirliğini koruyan sade görünüm.

Filtre ihtiyacı test edilmeden yeni filo menüsü veya karmaşık tablo
oluşturulmayacaktır.

### Aşama 4 — Görev çeşitliliğini bir sistemle artır

**Durum: Planlandı; temel denge sonrasında**

Aynı kısa rotayı sürekli tekrar etmenin en iyi strateji olmasını engellemek için
aşağıdaki seçeneklerden yalnızca biri ilk deney olarak eklenmelidir:

1. **Liman uzmanlaşması:** Bazı limanlarda belirli kargolar daha sık veya biraz
   daha değerli olur.
2. **Hafif talep sistemi:** Bir rota veya kargo sık kullanıldığında primi geçici
   olarak azalır, başka seçenekler öne çıkar.
3. **Benzersiz rota / ilk teslimat bonusu:** Oyuncuyu yeni liman çiftlerini
   denemeye teşvik eder.
4. **Bölgesel kontratlar:** Belirli bir bölgede birkaç bağlantılı teslimat sunar.

Önerilen ilk aday liman uzmanlaşmasıdır; haritayı anlamlı kılar, kolay anlatılır
ve sürekli dalgalanan pazar ekranı gerektirmez. Etkisi ölçülmeden arz-talep,
depolama, nadirlik ve kontrat sistemi birlikte eklenmemelidir.

### Aşama 5 — Görsel ve sesli dikey dil

**Durum: Planlandı**

- Nihai görsel stil piksel sanat olmayacaktır; okunaklı stilize 2D yön aranır.
- Kara parçaları, limanlar, gemiler ve görev işaretleri aynı görsel dilde
  yeniden tasarlanır.
- Görev rozetleri sade ünlem veya kolay okunan bir işaret biçimine getirilir.
- Deniz yüzeyine düşük yoğunlukta sürekli hareket eklenir.
- Limanda bekleyen gemiler çok hafif deniz salınımı yapar; gerçek konum ve
  dokunma alanı sabit kalır.
- Görev kabulü, hareket, yükleme, boşaltma, para, CV ve seviye artışı için tek
  güçlü geri bildirim seçilir; efekt kalabalığı oluşturulmaz.
- Liman ambiyansı, motor, yükleme, teslimat ve satın alma efektleri eklenir.
- Yormayan arka plan müziği hazırlanır.
- Efekt ve müzik mevcut ayrı ses kanallarına bağlanır.

Önce bir gemi, bir liman ve tek görev döngüsünde küçük bir “dikey dil” denenir;
bütün oyunun sanatı tek seferde değiştirilmez.

### Aşama 6 — Basit bakım ve risk sistemi

**Durum: Planlandı, kesin tasarım değil**

Oyuncunun yalnızca para kazanmadığını, şirket işletme kararları verdiğini
hissettirmek için ileride şu giderler değerlendirilebilir:

- Sefer masrafının daha görünür dengesi.
- Öngörülebilir bakım gideri.
- Kısa ve nadir gemi dinlenme/bakım süresi.
- Çok ileride sade liman işletme giderleri.

İlk sürümde rastgele büyük para kaybı, sık arıza, karmaşık personel yönetimi,
manuel yakıt doldurma ve oyuncuyu çalışır gemisiz bırakma yapılmamalıdır.
Bakım sistemi gelirse önce önceden görülebilen, planlanabilir ve kısa bir karar
olmalıdır. Reklam izletmek için yapay arıza yaratılmamalıdır.

### Aşama 7 — Kanal yatırımları

**Durum: İleri dönem planı**

Kara parçalarındaki seçilmiş dar geçitlerde Cash ve uygun Company Level ile
kanal açılması düşünülmektedir. Kanal:

- Yeni ve daha kısa deniz koridoru açar.
- Bazı görevlerin süresini ve masrafını azaltır.
- Harita üzerinde görünür, kalıcı şirket yatırımı olur.
- Mevcut rotaları otomatik olarak daha verimli yola yönlendirebilir.

Bu özellik harita yerleşimini, rota seçimini ve ekonomiyi yüksek derecede
etkiler. Bu nedenle yalnızca mevcut ağın dengesi ve nihai kara tasarımı
oturduktan sonra yapılmalıdır. Her kara parçasına serbest çizim yerine az sayıda
özel kanal noktası daha basit ve okunabilir çözümdür.

### Aşama 8 — Çevrimdışı otomasyonu yeniden değerlendirme

**Durum: Askıda**

Mevcut davranışta başlamış görevler kapalıyken ilerler, fakat gemiler yeni görev
almaz. İleride uzun görevler ve ekonomi dengesi anlamlı hale geldiğinde gemi
başına otomasyon şu sınırlardan biriyle çevrimdışına genişletilebilir:

- Belirli saat sınırı.
- Belirli sefer sayısı.
- Açıkça görünen otomasyon kapasitesi.

Sınırsız çevrimdışı görev zinciri ekonomi şişmesine ve aktif oynamanın
değersizleşmesine yol açacağı için kullanılmamalıdır.

### Aşama 9 — Ticari model ve yayın hazırlığı

**Durum: Planlandı; ekonomi tamamlanmadan uygulanmayacak**

Project Harbor'dan ticari gelir elde edilmesi hedeflenir. Öncelikli adaylar:

- Oyuncunun isteyerek izlediği ödüllü reklamlar.
- Düşük fiyatlı, açık değer sunan uygulama içi satın alımlar.
- Reklamsız sürüm veya reklam kaldırma seçeneği.
- Zaman kazanımı sağlayan ancak zorunlu olmayan küçük kolaylıklar.

Uygun ödül örnekleri ileride şunlar olabilir:

- Küçük bir Cash desteği.
- Nadir bakım beklemesini bir kez kısaltma.
- Sınırlı süreli ek kontrat seçeneği.
- Çevrimdışı özet ödülüne ölçülü bonus.

Kaçınılacak uygulamalar:

- Gemiyi bilerek bozup reklam izlemeye zorlama.
- Reklam izlemeden ilerlenemeyen ekonomi.
- Company Value veya Company Level'ı doğrudan sınırsız satma.
- Sürekli tam ekran zorunlu reklamlarla kısa oyun döngüsünü bölme.

Monetizasyon eklenmeden önce üretim imzası, sürüm numaralandırma, Google Play
gereksinimleri, gizlilik metni, Android performansı, kayıt uyumu ve gerçek cihaz
test matrisi hazırlanmalıdır.

---

## 7. Fikir havuzu ve oyuna etkileri

| Fikir | Durum | Oyuna etkisi | Ana risk |
|---|---|---|---|
| Uzun kontratlar | İlk sürüm çalışıyor, genişleme planlı | Orta/ileri oyuna uzun hedef verir | Ödül ve süre dengesini şişirmek |
| Liman uzmanlaşması | Planlandı | Haritanın tamamını kullanmayı teşvik eder | Fazla kural ve ikon kalabalığı |
| Hafif arz-talep | Plan adayı | Tek rota sömürüsünü azaltır | Mobil oyuncu için pazar karmaşası |
| Kanal yapımı | İleri plan | Haritayı stratejik yatırıma dönüştürür | Rota ve ekonomi dengesini kökten değiştirir |
| Deniz hareketi ve gemi salınımı | Planlandı | Dünyayı canlı gösterir | Dokunma alanı ve performans bozulması |
| Bakım/arıza | Planlandı | Gider ve filo planlaması ekler | Ceza veya reklam baskısı hissi |
| Maaş ve liman kirası | Fikir | Geç oyun para çıkışı sağlar | Pasif cezaya ve anlaşılmaz zarara dönüşmek |
| Ayrı yakıt tankı | Askıda | Gerçekçilik ve rota planı sağlayabilir | Mikro yönetim ve oyuncunun kilitlenmesi |
| Çevrimdışı otomatik görev | Askıda | Idle ilerlemeyi güçlendirir | Aktif oyunu değersizleştiren sınırsız kazanç |
| 12'den fazla liman | Sonraki bölge adayı | Uzun vadeli içerik büyümesi | Mevcut içeriği dengelemeden kapsam şişmesi |
| Büyük filo filtreleri | Planlandı | 10+ gemiyi okunabilir kılar | Erken oyunda gereksiz arayüz |
| Ödüllü reklam | Planlandı | Ticari gelir ve isteğe bağlı kolaylık | Zorlayıcı tasarım ve ekonomi bozulması |

---

## 8. Kesin olarak yapmayacağımız veya şimdilik istemediğimiz şeyler

### Kapsam dışı

- Gemiyi elle sürmek.
- Gerçekçi denizcilik veya yakıt simülasyonu.
- Çok oyunculu mod ve oyuncular arası ticaret.
- Gerçek dünya ölçeğinde süre ve mesafe.
- Her küçük özellik için yeni manager/sistem katmanı.
- Zorunlu tersane dönüşü ve refit yolculuğu.

### Alınmış görsel kararlar

- Piksel sanat yönünden vazgeçildi.
- Nihai görseller henüz seçilmedi; stilize ve mobilde okunabilir 2D hedefleniyor.
- Dairesel seçim halkaları yerine nesnenin kendi şeklini izleyen vurgu kullanılır.

### Bilinçli olarak askıda tutulanlar

- Oyun kapalıyken otomasyonun sürekli yeni görev alması.
- Ayrıntılı yakıt tankı ve yakıt satın alma ekranı.
- Kaptan/personel yönetimi.
- Karmaşık arz-talep, depolama ve pazar dalgalanması.
- Yeni kıtalar veya 12 limanın ötesinde genişleme.

---

## 9. Denge ve tasarımda açık kararlar

Henüz kesinleşmeyen ana konular:

- 20–30 saatlik oyunda nihai görev süresi eğrisi.
- Nihai görev ödülleri ve sefer masrafı oranları.
- İkinci, üçüncü ve sonraki gemilere ulaşma süresi.
- 15 Company Level eşiğinin nihai varlık ekonomisi.
- Liman geliştirme maliyetlerinin geri dönüş süresi.
- Büyük Kontratların daha uzun sürümlerinin sayısı ve primi.
- 10+ gemi için gerçekten hangi filtrelerin gerekli olduğu.
- Bakım/arıza sisteminin oyuna girip girmeyeceği.
- İlk rota çeşitliliği sisteminin liman uzmanlaşması mı, talep mi olacağı.
- Kanal noktalarının kesin yeri ve bedelleri.
- Nihai görsel dil, ikonlar, animasyon süreleri, sesler ve müzik.
- Reklam ve uygulama içi satın alma ödüllerinin miktarı ve sıklığı.

Bu kararlar masa başında yalnızca formülle değil, gerçek Android oturumlarıyla
verilmelidir.

---

## 10. MVP ve kalite hedefi

Project Harbor'ın ilk güçlü oynanabilir sürümü aşağıdakileri sağlamalıdır:

- Yeni oyuncu yardım almadan ilk gemisini alıp ilk görevini tamamlayabilmeli.
- İkinci gemiye ulaşarak iki görevi paralel yönetebilmeli.
- Yeni liman açma ve liman geliştirme kararını anlayabilmeli.
- En az iki gemi uzmanlığı arasında anlamlı fark görebilmeli.
- Cash, Company Value ve Company Level farkını anlayabilmeli.
- Kaydı kapatıp açınca para, filo, liman, görev ve gemi konumu doğru dönmeli.
- Uzak görevler ile çevrimdışı ilerleme gerçek bir değer sağlamalı.
- Rotalar kara üzerinden geçmemeli ve mobil ekranda okunabilir olmalı.
- 10+ gemiye büyüme teknik olarak mümkün, görsel olarak yönetilebilir olmalı.
- Ekonomi oyuncuyu ne birkaç dakikada zengin etmeli ne de kalıcı kilitlemeli.
- Geçici test düğmeleri üretim sürümünde görünmemeli.
- Android sürümü imzalı, güncellenebilir ve gerçek cihazlarda kararlı olmalı.

---

## 11. Çalışma yöntemi

Her yeni özellikte şu sıra korunur:

1. Özelliğin oyuncuya ve ekonomiye katkısı değerlendirilir.
2. Mevcut sistemlerden hangisinin davranışı sahiplenmesi gerektiği belirlenir.
3. En az dosyaya dokunan küçük, oynanabilir ilk sürüm yapılır.
4. Godot 4.7.1 sözdizimi, sinyaller, null güvenliği ve kayıt uyumu test edilir.
5. Görsel/dokunmatik değişiklik Android cihazda denenir.
6. Kalıcı oyuncu kararıysa GDD güncellenir.
7. Değişiklik anlamlı tek commit halinde kaydedilip istenirse push edilir.

Geçici test değerleri GDD'ye nihai kural gibi yazılmaz. Çalışan kod gereksiz
yere yeniden kurulmaz. “İleride gerekebilir” gerekçesi tek başına yeni sistem
eklemek için yeterli değildir.

---

## 12. Kısa gelecek özeti

Project Harbor şu anda temel şirket büyütme döngüsüne sahip oynanabilir bir
prototiptir. En doğru sonraki yön yeni sistemleri hızla eklemek değil:

```text
12 limanlık ekonomiyi ölç
↓
Süre, ödül ve yatırımları dengele
↓
Mevcut sistemleri bağlamsal olarak öğret
↓
Büyük filo kullanılabilirliğini gerçek cihazda doğrula
↓
Tek bir rota çeşitliliği mekaniği ekle
↓
Görsel ve sesli dikey dili oluştur
↓
Bakım, kanal, çevrimdışı otomasyon ve monetizasyonu sırayla değerlendir
```

Başarı ölçütü yalnızca özellik sayısı değildir. Oyuncu her saat yeni ve anlaşılır
bir şirket hedefi görmeli; verdiği kararların filosunu, liman ağını ve haritadaki
şirket varlığını büyüttüğünü hissetmelidir.
