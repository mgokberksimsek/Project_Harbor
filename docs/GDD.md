# Project Harbor — Game Design Document

> Durum: Yaşayan belge<br>
> Tür: 2D liman ve filo yönetimi / tycoon<br>
> Motor: Godot 4<br>
> Öncelikli platform: Android mobil<br>
> Ekran yönü: Yatay (landscape)<br>
> Oyun modu: Tek oyunculu

Bu belge Project Harbor'ın oyuncu deneyimi ve oyun tasarımı için ana başvuru
kaynağıdır. Yeni bir mekanik kesinleştiğinde bu belge de güncellenir. Kodun
nasıl düzenlendiği için `docs/ARCHITECTURE.md` kullanılmalıdır.

## 1. Oyun özeti

Project Harbor, oyuncunun küçük bir yük gemisiyle başlayıp limanlar arasında
ticaret görevleri tamamladığı, filosunu büyüttüğü ve yeni deniz rotaları açtığı
mobil bir yönetim oyunudur.

Oyuncu bir gemi seçer, dünya üzerindeki görev simgelerinden o gemiye uygun
teklifleri inceler ve bir görev atar. Gemi gerekiyorsa önce başka bir limana
yük almaya gider, kısa bir yükleme sürecinden sonra teslimat limanına doğru
yola çıkar. Tamamlanan görevlerden kazanılan para yeni limanlar, gemiler ve
gemi geliştirmeleri için kullanılır.

Uzun vadeli amaç, küçük bir bölgesel taşımacılık işletmesini çok sayıda limana
ve uzmanlaşmış gemiye sahip büyük bir denizcilik ağına dönüştürmektir.

## 2. Tasarım hedefleri

### 2.1 Kolay anlaşılır, giderek derinleşen yönetim

İlk dakikalarda oyuncu tek gemi ve kısa görevlerle temel döngüyü hemen
öğrenebilmelidir. Yeni limanlar, gemiler, kargo gereksinimleri ve daha uzun
görevler zaman içinde açılarak karar alanını genişletmelidir.

### 2.2 Haritada canlı ve okunabilir deniz trafiği

Gemiler yalnızca süre sayaçları olarak değil, harita üzerinde gerçek rotaları
izleyen varlıklar olarak görülmelidir. Rotalar kara parçalarının çevresinden
geçmeli; kıvrımlı, kırmızı ve kesikli çizgiler geminin planlanan yolunu açıkça
göstermelidir.

### 2.3 Kısa aktif oturum ile uzun süreli ilerlemeyi birleştirmek

Oyunun başında görevler kısa sürer ve oyuncu uygulama açıkken sık karar verir.
Gelişim ilerledikçe görevler uzar. Zaman damgasına dayalı sistem sayesinde
uzun görevler uygulama kapalıyken de ilerleyebilir. Böylece ilk oyun hızlı,
ileri oyun ise daha stratejik ve rahat tempolu olur.

### 2.4 Her yeni satın alımın anlamlı olması

Yeni gemiler artan fiyatlarla satın alınmalı ve filo sınırsız büyümemelidir.
Gemi hızı ve kapasitesi de sınırlı seviyelerde geliştirilmelidir. Oyuncu her
harcamada kısa vadeli kazanç ile uzun vadeli büyüme arasında seçim yapmalıdır.

### 2.5 Basitlik önceliği

Project Harbor kolay öğrenilen, az sayıda açık kararla yönetilen bir mobil
tycoon olarak kalmalıdır. Yeni bir sistem ancak oyuncuya anlamlı ve kolay
açıklanabilen bir karar katıyorsa eklenir. Gerçekçilik uğruna zorunlu seyahat,
bekleme, tekrarlanan bakım veya gereksiz mikro yönetim oluşturulmaz. Aynı amacı
daha az adımla karşılayan çözüm her zaman tercih edilir.

Yeni satın alınan gemiler şirket merkezinin açık deniz tarafında belirir,
teslimat iskelesindeki boş bir yuvaya kısa bir yanaşma hareketi yapar ve ilk
görevlerini alana kadar burada bekler. Oyuncu ilk gemisini
öğreticinin ilk adımında satın alır; başlangıç gemisi de aynı merkez akışını
izler. Görev seçildiğinde gemi merkezden yumuşakça ayrılır ve ilk yük limanına
normal rota hızıyla gider. Bu yalnızca görsel bir teslimat akışıdır; oyuncuya
ek işlem veya bekleme yüklemez.

### 2.6 Şirket büyütme hissi

Project Harbor'ın temel fantezisi “gemimi sürüyorum” değil, “şirketimi
büyütüyorum” olmalıdır. Oyuncu tek gemi ve iki limanla başlayan küçük
işletmesinin zamanla çok gemili, çok bölgeli bir lojistik ağına dönüştüğünü
açıkça görmelidir. Yeni bir sistem; filo, liman ağı veya anlamlı şirket
kararlarından en az birini güçlendirmiyorsa gerekli olup olmadığı sorgulanır.

Oyun birbirini güçlendiren az sayıda kaliteli sistemle büyütülür. Aynı oyuncu
değerini sağlayan iki seçenek arasında daha küçük ve daha kolay açıklanan
özellik tercih edilir; yalnızca gelecekte yararlı olabileceği için yeni bir
mekanik eklenmez.

## 3. Hedef oyuncu ve deneyim

- Kısa oturumlarla ilerlemek isteyen mobil oyuncular.
- Yönetim, tycoon ve idle oyunlarını seven ancak karmaşık tablolar istemeyenler.
- Harita üzerinde hareket eden araçları ve ağ kurma hissini sevenler.
- İlk oturum hedefi: Bir görev seçmek, gemiyi izlemek ve ödülü almak.
- Orta vadeli hedef: İkinci gemiyi satın alıp aynı anda birden fazla görevi
  yönetmek.
- Uzun vadeli hedef: Yaklaşık 12 limanlık bir ağ ve farklı görevlere uygun,
  geliştirilmiş bir filo kurmak.

## 4. Temel oyun döngüsü

1. Harita veya filo panelinden boş bir gemi seçilir.
2. Seçilen geminin taşıyabildiği kargolara uygun görev işaretleri limanlarda
   görünür.
3. Bir limandaki küçük görev simgesine dokunulur.
4. O limandan alınabilecek üç görev teklifi incelenir.
5. Bir görev seçilir ve gemi otomatik olarak yola çıkar.
6. Gemi yükün bulunduğu limana gider veya zaten oradaysa liman merkezine geçer.
7. Liman merkezinde yükleme süresi tamamlanır.
8. Gemi teslimat limanına gider, boş bir yuvaya yanaşır ve boşaltma yapar.
9. Ödül alınır; para yeni liman, gemi veya geliştirmeye harcanır.
10. Daha geniş ve verimli bir taşıma ağı kurmak için döngü tekrarlanır.

## 5. Oyun başlangıcı ve ilerleme

### 5.1 Başlangıç durumu

Mevcut prototipte oyuncu:

- Sıfır gemiyle başlar.
- Başlangıç yük gemisini satın almaya tam yetecek 500 TL'ye sahiptir.
- Mersin ve İzmir limanları açık başlar.
- Yeni harita yerleşimindeki ilk genişleme hedefi Antalya'dır. Ardından
  Çanakkale, İstanbul, Samsun ve Trabzon açılarak ağ yakından uzağa büyür.
- İlk gemiyi satın aldıktan sonra kasası sıfırlanır ve ilk yeni parasını
  görevlerden kazanır.
- Bir gemi seçildiğinde o gemiye ait üç görev teklifi görür.

Başlangıç limanları birbirine görece yakın tutulur. Amaç oyuncuya kısa sürede
ilk hareketi, yüklemeyi, teslimatı ve ödülü göstermektir.

Prototip denge hedefinde ilk genişleme limanı mevcut başlangıç görevleriyle
3–4 görevde, ikinci gemi de genişleyen rota havuzuyla sonraki 3–4 görevde
alınabilmelidir. Böylece öğreticiden iki gemili filoya geçiş toplam 6–8 görev
bandında kalır. Bu bant otomatik denge testinde veri ve ödül formüllerinden
hesaplanır; nihai gerçek zaman süreleri daha sonraki oynanış testinde belirlenir.

### 5.2 İlerleme katmanları

Oyuncunun gelişimi dört ana eksende ilerler:

- **Harita genişlemesi:** Para ödeyerek yeni limanların açılması.
- **Filo büyümesi:** Artan fiyatlarla yeni gemilerin satın alınması.
- **Gemi gelişimi:** Hız ve kargo kapasitesi seviyelerinin artırılması.
- **Uzmanlaşma:** Soğutmalı yük gibi özel yetenek isteyen kargolar için uygun
  gemilerin edinilmesi.

Bu yatırımlar şirketin harcanmayan ilerleme ölçüsü olan Company Value'yu
artırır. Ulaşılan Company Value eşikleri kalıcı Company Level seviyelerini
açar.

### 5.3 Company Value ve Company Level

Cash yalnızca harcanabilir paradır ve Company Value hesabına doğrudan girmez.
İlk sürümde Company Value mümkün olduğunca sade tutulur:

```text
Company Value = Gemi Değeri + Gemi Geliştirmeleri + Açık Limanların Değeri
```

Şirket merkezi ve teknolojiler eklendiğinde kendi sabit varlık değerleriyle bu
toplama dahil edilir. Tamamlanan görev, taşınan yük, rota çeşitliliği, Cash ve
geçici verimlilik çarpanları ilk sürümde Company Value üretmez.

Şirket merkezi, yeni bir yönetim katmanı oluşturmadan büyümeyi haritada görünür
kılar. Prototipte Company Level 1–2 küçük ofis, 3–5 büyümüş merkez, 6–9 bölgesel
merkez ve 10–15 kule görünümünü kullanır. Bu kademeler otomatik ve yalnızca
görseldir; oyuncudan ayrıca para, yükseltme işlemi veya merkeze dönüş istemez.

Company Level, şimdiye kadar ulaşılan en yüksek Company Value üzerinden
hesaplanır. Company Value daha sonra düşse bile seviye düşmez ve açılan içerik
yeniden kilitlenmez. Company Level yeni gemi, liman bölgesi, teknoloji, filo
kapasitesi ve şirket merkezi aşamalarını kullanılabilir hale getirir; oyuncu
bu içeriği almak için ayrıca Cash öder.

Nihai 15 seviyelik eşikler, bütün gemi, liman, teknoloji ve merkez varlık
değerleri çıkarıldıktan sonra dengelenecektir. Mevcut eşikler prototip ve test
değerleridir.

Üst arayüzdeki Company Level göstergesine dokunulduğunda kompakt bir ilerleme
özeti açılır. Bu özet toplam Company Value'yu filo ve liman yatırımları olarak
ayırır, mevcut seviyedeki ilerleme çubuğunu gösterir ve bir sonraki Company
Level'da açılacak veri tanımlı gemi ve limanları listeler. Amaç yeni bir yönetim
katmanı eklemek değil, oyuncuya bir sonraki yatırım hedefini açıkça göstermektir.

### 5.4 Uzun vadeli dünya hedefi

Tam sürüm için yaklaşık 12 açılabilir liman hedeflenir. Dünya, büyük kara
parçalarından ve bunların kıyılarındaki limanlardan oluşur. Gemiler karaların
içinden geçemez; tanımlı deniz koridorlarını ve kıvrımlı rotaları izler.

Harita ilk bölgedeki limanları yakın ve anlaşılır tutmalı, yeni bölgeler
açıldıkça mesafeleri ve rota karmaşıklığını kademeli artırmalıdır.
İlk bölgesel ağ Türkiye kıyılarındaki limanlarla büyür; daha sonraki uzak bölge
genişlemelerinde yabancı limanlar kullanılarak yeni bir ölçek duygusu yaratılır.
On iki limanlık ilk ağın dış bölge adayları Pire, Varna, Batum, Girne ve
İskenderiye'dir. Sağ alttaki büyük kara parçasında Girne ile İskenderiye zıt
kıyılara yerleşerek aynı bölgeye iki farklı deniz yaklaşımı sağlar.

Başlangıç kompozisyonunda Mersin ve şirket merkezi büyük ana karanın güney
kıyısında, İzmir ise ana karaya yakın ayrı bir adanın kıyısında bulunur. Antalya
ilk genişleme hedefi olarak aynı başlangıç görünümünde kalır. Böylece ilk kısa
rotalar anlaşılır olurken oyuncu daha ilk dakikada ada ile ana kara arasında
taşımacılık yaptığını görür.

Dış bölgelerdeki kara parçalarının bazıları ileride daha büyük adalar halinde
birleştirilebilir. Haritada az sayıda doğal dar boğaz bırakılması, ileri oyunda
satın alınabilen kanal yatırımlarına alan sağlar. Kanal açıldığında daha kısa
deniz koridorları kullanılabilmelidir; bu özellik ilk harita yerleşiminin değil,
ilerideki altyapı ilerlemesinin parçasıdır.

Prototip genişleme sırası ve mevcut test paketleri şöyledir:

- Antalya: Şirket Sv. 1, `750 ₺`, `500 CV`.
- Çanakkale: Şirket Sv. 3, `1.500 ₺`, `800 CV`.
- İstanbul: Şirket Sv. 4, `2.600 ₺`, `1.200 CV`.
- Samsun: Şirket Sv. 5, `4.200 ₺`, `2.000 CV`.
- Trabzon: Şirket Sv. 6, `6.500 ₺`, `3.000 CV`.
- Pire: Şirket Sv. 7, `8.500 ₺`, `4.200 CV`.
- Varna: Şirket Sv. 8, `11.000 ₺`, `5.500 CV`.
- Batum: Şirket Sv. 9, `14.500 ₺`, `7.200 CV`.

Bu değerler nihai ekonomi dengesi değildir; mevcut haritada yakından uzağa
genişleme ve Company Level akışını test etmek içindir.

## 6. Limanlar

Her limanın şu temel özellikleri vardır:

- Benzersiz kimlik ve görünen ad.
- Dünya üzerindeki konum.
- Kilit durumu ve açma maliyeti.
- Seviye ve ileride kullanılacak geliştirme maliyetleri.
- Ekonomik kademe ve seviye ödül çarpanı.
- Seviyeye bağlı yükleme ve boşaltma süresi.
- Birden fazla gemi için tanımlı yanaşma yuvaları.
- Bağlı olduğu deniz rotaları.

Kilitli limana dokunulduğunda doğrudan para harcanmaz. Önce limanın açıklamasını,
açma bedelini, gereken ve mevcut Şirket Seviyesini, mevcut kasayı ve sağlayacağı
Company Value katkısını gösteren kompakt bir onay paneli açılır. Koşullar
sağlanmıyorsa açma düğmesi eksik para veya seviye nedenini göstererek devre dışı
kalır. Liman yalnızca oyuncu etkin açma düğmesine dokunduğunda satın alınır.
Açık limana dokunmak, seçili gemi varsa o limandaki uygun görev tekliflerini
gösterir. Seçili gemi yoksa aynı dokunuş kompakt liman geliştirme panelini
açar; böylece görev verme akışına yeni bir adım eklenmez.

Prototipte her liman en fazla üç seviyedir. Seviye 2 limanın görev geliri
etkisini `%8` artırır ve yük işlemlerini `%20` hızlandırır. Seviye 3 bu
değerleri `%16` gelir etkisine ve `%40` işlem hızına çıkarır. Bir görevin iki
limanındaki gelir çarpanları ortalandığı için bu artış görevin toplam ödülüne
iki kez uygulanmaz. Her geliştirme Cash harcar ve veri dosyasında tanımlı sabit
Company Value katkısı sağlar; ayrıca Company Level şartı istemez.

Bir limanda birden fazla gemi bulunduğunda gemiler üst üste binmez. Yeni gelen
gemi ilk boş yuvaya yerleşir. Daha öndeki bir yuva boşaldığında en sondaki gemi
o yuvaya yumuşak biçimde geçerek görünümü kompakt tutar.

## 7. Gemiler ve filo yönetimi

### 7.1 Gemi özellikleri

Her gemi modeli veri odaklı olarak aşağıdaki özelliklere sahiptir:

- Temel hız.
- Başlangıç kargo kapasitesi.
- Taşıyabildiği kargo sınıfları.
- Satın alma taban fiyatı.
- Hız ve kapasite geliştirme maliyetleri.
- Azami hız ve kapasite seviyeleri.
- Görsel ve sahne bilgisi.
- Sefer masrafında kullanılan yakıt tüketimi ve ileride değerlendirilebilecek
  yakıt kapasitesi.

### 7.2 Gemi durumları

Bir gemi aşağıdaki açık durum makinesini izler:

`Boşta → Yük Limanına Gidiyor → Yükleniyor → Teslimata Gidiyor → Boşaltıyor → Boşta`

Gemi bulunduğu limandan yük alacaksa yolculuk ayağı atlanır ancak yükleme yine
liman merkezinde yapılır. Başka limandan yük alacaksa yuvadan doğrudan deniz
rotasına çıkar, mevcut limanın merkezine gereksiz yere uğramaz.

### 7.3 Satın alma ve filo sınırı

Filoya alınan her yeni gemi, modelinden bağımsız olarak mağazadaki bütün gemi
fiyatlarını artırır. Mevcut prototip formülü her modelin taban fiyatını toplam
sahip olunan gemi sayısı için `1,6` katsayısıyla büyütür ve fiyatı en yakın
10'a yuvarlar. Böylece oyuncu sürekli farklı modeller alarak fiyat artışını
atlayamaz.

Bir gemi modelinin satın alınabilmesi için gereken Company Level'a ulaşılmış
olmalı ve güncel Cash fiyatı ayrıca ödenmelidir.

Gemi mağazası modelleri gerekli seviye ve fiyata göre sıralar. Oyuncu kompakt
sağ/sol oklarla modeller arasında geçer; kilitli modeller görülebilir ancak
gereken Company Level'a ulaşılmadan satın alınamaz. Prototipte Başlangıç Yük
Gemisi genel, Soğutmalı Yük Gemisi genel ve soğutmalı, Dökme Yük Gemisi ise
yalnızca dökme yük sınıfında görev alır.

Filo sonsuza kadar büyümez. Prototipte üst sınır 6 gemidir. Nihai sınır ve bu
sınırı artırabilecek liman/ofis geliştirmeleri dengeleme aşamasında
kararlaştırılacaktır.

### 7.4 Geliştirmeler

- Her hız seviyesi temel hıza mevcut prototipte `%15` ekler.
- Hız geliştirmesi en fazla 5 seviyedir.
- Kapasite geliştirmesi en fazla 3 seviyedir.
- Görevde rastgele kullanılan her ilave kapasite birimi brüt ödülü `%25`
  artırır; böylece kapasite yatırımı anlamlıdır ancak yeni geminin sağladığı
  paralel çalışma gücünün yerini almaz.
- Geliştirme maliyetleri her seviyede katlanarak artar.
- Hiçbir gemi sonsuza kadar hızlandırılamaz veya kapasite kazanamaz.
- Gemi geliştirmeleri, gemi nerede olursa olsun satın alındığı anda uygulanır.
- Geliştirme için merkeze ya da tersaneye dönme, refit yolculuğu veya zorunlu
  bekleme bulunmaz.

### 7.5 Otomatik görev

- Otomatik görev gemi başına açılır; tüm filoyu tek seferde otomatikleştirmez.
- İlk sürümde Şirket Seviyesi 7, gemide toplam 4 hız/kapasite geliştirmesi ve
  tek seferlik 5.000 ₺ yatırım gerekir.
- Açıldıktan sonra ücretsiz olarak açılıp kapatılabilir.
- Oyun açıkken boşta kalan gemi, net kazancı pozitif teklifler arasından tahmini
  süre başına en yüksek net kazancı sağlayanı seçer.
- Oyuncu otomasyonu kapattığında mevcut görev tamamlanır, yeni görev alınmaz.
- İlk sürüm çevrimdışıyken arka arkaya yeni görev üretmez; yalnızca önceden
  başlamış görevin zaman bazlı ilerlemesi uygulanır.

Çevrimdışı otomasyonu genişletmeden önce Company Level ve bölge ilerlemesiyle
orta/uzun görevler açılmalıdır. Bir dakikadan kısa prototip görevlerini
çevrimdışı tamamlamak tek başına anlamlı bir idle döngü sayılmaz. İleri aşamada
otomasyonun uygulama kapalıyken görev zincirlemesi değerlendirilirse sınırsız
kazanç yerine açıkça gösterilen bir süre veya sefer sınırı kullanılmalıdır.

### 7.6 Gemi kimliği ve isimlendirme

- Satın alınan her gemiye filoda kullanılmayan, denizcilik veya keşif temalı
  rastgele bir isim verilir.
- Özel gemi adı ile gemi modeli filo kartında birlikte gösterilir.
- Oyuncu filo kartındaki kalem düğmesiyle geminin adını ücretsiz değiştirebilir.
- Yeniden adlandırma penceresindeki zar düğmesi kullanılmayan yeni bir isim
  önerir; oyuncu öneriyi onaylayabilir veya düzenleyebilir.
- Gemi adları 2–20 karakterdir ve aynı filoda büyük-küçük harf farkıyla
  tekrarlanamaz. İsimler Cash, CV veya görev performansını etkilemez.
- Gemi isimleri kayıt verisinde saklanır. İsim alanı bulunmayan eski kayıtlara
  mevcut gemi kimliğine göre kararlı ve benzersiz isimler atanır.

## 8. Görev sistemi

### 8.1 Teklif üretimi

- Görevler rastgele oluşturulur.
- Seçili ve boşta olan her gemi için aynı anda üç teklif sunulur.
- Teklifler yalnızca geminin taşıyabildiği kargolardan üretilir.
- Yükleme ve teslimat limanı aynı olamaz.
- Görev, geminin bulunduğu limandan başlamak zorunda değildir.
- Aynı içeriğe sahip teklifler arayüzde ayrı ayrı tekrarlanmaz.
- Kilidi açılmamış limanlar normal görev havuzunda yer almaz.
- Doğrudan koridoru olmasa bile deniz ağı üzerinden birbirine bağlı her açık
  liman çifti arasında görev üretilebilir.

### 8.2 Teklif bilgileri

Her görev kartı en az şu bilgileri göstermelidir:

- Yükleme limanı.
- Teslimat limanı.
- Kargo türü ve miktarı.
- Tahmini toplam süre.
- Brüt ödül.
- Tahmini sefer masrafı ve net kazanç.

### 8.3 Görev seçme akışı

Oyuncu önce gemiyi seçer. Haritadaki uygun yükleme limanlarında küçük görev
simgeleri görünür. Simgeye dokunulduğunda yalnızca ilgili limandaki ve seçili
gemiye uygun teklifler kompakt bir alt panelde açılır.

Görev kabul edildiğinde panel kapanır, seçili gemiye görev atanır ve bütün rota
tek seferde gösterilir. Örneğin İzmir'deki bir gemi Mersin'den yük alıp
İstanbul'a teslim edecekse hem İzmir–Mersin hem Mersin–İstanbul ayağı görünür.

### 8.4 Süre sınıfları

Görevler ileride kısa, orta ve uzun olarak dengelenecektir:

- **Kısa:** Oyunun başında, uygulama açıkken sık etkileşim için.
- **Orta:** Gelişmiş oyuncunun birkaç gemiyi paralel yönetmesi için.
- **Uzun:** Uygulama kapalıyken de ilerleyen ileri oyun görevleri için.

Prototipte başlangıç rotaları yaklaşık yarım dakika sürerken mevcut haritanın
uzak bölgesel rotaları yaklaşık bir dakikaya yaklaşır. Bu sayılar
testleri hızlandırmaya devam eder ve nihai denge değildir.

Aynı gemiyle aynı yükü aynı iki liman arasında taşıyan görevin süresi yalnızca
şirket büyüdüğü için artmaz. Şirket ilerlemesi daha uzak bölgeleri ve daha uzun
görevleri açar; eski kısa rotalar hızlı sefer seçeneği olarak kalır. Mevcut
bölgesel rotalar açık rota mesafesine göre saniyeler veya birkaç dakika sürer.
İleride eklenecek uzak yabancı bölgeler ve büyük kontratlar 20–60 dakikalık ve
daha uzun seferleri taşır.

Stilize haritadaki görsel mesafe ile oynanış mesafesi rota verisinde ayrılabilir.
Oynanış mesafesi süreyi, ödülü ve sefer masrafını birlikte etkiler; yalnızca
süreyi uzatıp uzun rotaları ekonomik olarak değersizleştirmez. İleri aşamada
aynı rotada çıkabilecek büyük kontratlar daha fazla kargo ve yükleme süresi
karşılığında daha yüksek ödül sunabilir, ancak ilk süre dengelemesine dahil
edilmez.

Görev süresi boş konumlanma yolculuğu, yükleme, yüklü teslimat yolculuğu ve
boşaltmanın toplamıdır. Geminin kaynak verisindeki hız nominal seyir hızıdır.
Prototipte Seviye 1 limanın yükleme ve boşaltma süreleri ayrı ayrı `3,0`
saniyedir. Bu süreler Seviye 2'de `2,4`, Seviye 3'te `1,8` saniyeye iner.
Değerler geliştirme etkisini görünür tutarken kısa görevleri beklemeye
dönüştürmeyecek test süreleridir.
Boş gemi bu hızdan %10 daha hızlı gider; yüklü gemi her kargo birimi için %5
yavaşlar ve toplam yavaşlama %20 ile sınırlıdır. Böylece gemi modeli, hız
geliştirmesi, rota mesafesi ve taşınan miktar süreyi anlaşılır biçimde etkiler.
Kargo türlerine ayrı ağırlık sınıfları ancak ileride somut bir oynanış ihtiyacı
oluşursa eklenir.

## 9. Rota, hareket ve liman animasyonları

- Deniz rotaları düz bağlantılar olmamalıdır. Kimi koridorlar geniş yaylar,
  kimileri ise birden fazla yön değiştiren yumuşak S-kıvrımları kullanmalıdır.
- Gemiler, yükleme ve teslimat limanları arasında tanımlı deniz koridorlarının
  oynanış mesafesine göre en kısa birleşimini kullanır. Bağlantı noktası olan
  ara limanların merkezine girmez; limanın açık deniz tarafındaki geçiş
  noktasını kullanır. Birleşik rota tek parça olarak gösterilir.
- Bütün kayıtlı rotaların yumuşatılmış merkez çizgileri, geliştirme testlerinde
  tüm kara poligonlarına karşı otomatik olarak doğrulanır. Doğrulama doğrudan
  koridorların yanında bütün liman çiftlerinden oluşan birleşik rotaları da
  kapsar. Aynı testler rota ağının düz çizgilere dönüşmemesini ve birden fazla
  S-kıvrımı içermesini korur.
- Görev süresi, gelir ve işletme masrafında kullanılan rota mesafeleri görsel
  deniz koridorlarının algılanan uzunluk sırasıyla tutarlı olmalıdır. Harita
  yerleşimi değiştiğinde eski mesafe değerleri yeni konumlara göre yeniden
  dengelenir; süre formülü ayrıca değiştirilmez.
- Tam görev rotası kırmızı, kesikli bir çizgiyle gösterilir.
- Boş konumlanma ve yüklü teslimat etapları aynı koridoru ters yönlerde
  kullanıyorsa ortak bölüm aynı merkez çizgisinde yalnızca bir kez çizilir.
  Böylece rota paralel şeritlere ayrılmaz ve üst üste gelen kesikler düz bir
  çizgiye dönüşmez. Ortak bölüm ileride yeniden kullanılacaksa ilk geçişte
  kaybolmaz; son geçiş tamamlandığında normal şekilde silinir.
- Gemi ilerledikçe geçtiği çizgi parçaları kaybolur; ilerideki parçalar yerinde
  kalır ve gemiye doğru kaymaz.
- Geminin burnu hareket ettiği rotanın teğetine hizalanır.
- Yuvadan çıkış, yük limanına giriş ve teslimat limanına yanaşma ani açı
  değişimleri olmadan yumuşak yapılır.
- Uzun sefer katsayısı açık deniz ilerlemesini uzatabilir ancak limanın son
  yaklaşma bölgesini ağır çekime dönüştürmez. Son yaklaşım görev süresinden
  bağımsız, kısa ve sabit bir görsel sürede tamamlanır. Yük alırken gemi önce
  gerçek giriş yönüne bakar, liman merkezine ulaştıktan sonra kalan yükleme
  süresinde çıkış rotasına yumuşakça döner.
- Başka limana yük almaya giden gemi mevcut liman merkezine uğramaz.
- Yükleme limanına ulaşan gemi yuvaya oturmadan liman merkezinde bekler ve
  ardından teslimat rotasına devam eder.
- Teslimat limanına ulaşan gemi yükünü liman merkezinde boşaltır; görünür
  boşaltma beklemesi tamamlandıktan sonra ayrılmış yuvaya yumuşakça geçer.
- Teslimattan sonra gemi ayrılmış boş yuvaya yumuşakça yerleşir.

## 10. Ekonomi

### 10.1 Gelir

Görev ödülü şu girdilerden oluşur:

- Kargonun temel değeri.
- Yükleme ile teslimat arasındaki mesafe.
- Kargo miktarı.
- Yükleme ve teslimat limanlarının ekonomik kademeleri ve seviye çarpanları.

Limanlar görev ekonomisi için dört kademeye ayrılır. Başlangıç limanları
`x1,00`, gelişen bölge limanları `x1,08`, uzak bölge limanları `x1,16` ve
prestij bölgesi limanları `x1,25` temel çarpan kullanır. Görevdeki iki limanın
çarpanları ortalanır ve sonuca yalnızca bir kez uygulanır. Böylece yeni
bölgeler daha yüksek toplam kazanç fırsatı yaratırken iki ileri limanın
çarpanları birbirini katlayıp ekonomiyi kontrolsüz büyütmez.

Mevcut prototipte Mersin ve İzmir kademe 1; Antalya ve Çanakkale kademe 2;
İstanbul ve Samsun kademe 3; Trabzon kademe 4'tür. Ekonomik kademe Company
Level'dan ayrı bir liman özelliğidir. Company Level içeriğe erişimi, ekonomik
kademe ise o bölgedeki görevlerin ölçülü gelir primini belirler.

Mevcut erken oyun ödülleri ve masrafları, 750 TL'lik ilk limana yaklaşık 3–5
görevde ulaşılacak şekilde dengelenir. Başlangıç gemisi satın alındıktan sonra
filo geneli fiyat artışıyla 1.280 TL olan ikinci gemi yaklaşık 4–8 görevlik bir
sonraki hedeftir. Nihai görev süreleri ve sefer masrafı oranları mobil oynanış
testlerinde birlikte yeniden değerlendirilir.

### 10.2 Giderler

Mevcut çalışan giderler:

- Yeni liman açma.
- Yeni gemi satın alma.
- Gemi hızını geliştirme.
- Gemi kapasitesini geliştirme.
- Görevin yükleme ve teslimat ayaklarının toplam mesafesiyle geminin tüketim
  oranına bağlı sefer masrafı.

Görev kartında net kazanç ilk sırada; brüt ödül ve sefer masrafı onun yanında
kabulden önce gösterilir. Teslimatta da gelir, masraf ve net kazanç tek satırlık
bir özetle bildirilir.
Başka limana yük almaya giden geminin boş seyir mesafesi de masrafa dahildir.
İlk sürümde ayrı yakıt tankı veya yakıt satın alma akışı yoktur; masraf görev
teslim edildiğinde brüt ödülden düşülür. Böylece oyuncu başlangıçta yakıt parası
kalmadığı için ilerleyemez duruma gelmez.

### 10.3 Denge ilkeleri

- İkinci gemi ulaşılabilir ancak anlamlı bir hedef olmalıdır.
- Her sonraki gemi daha fazla görev ve tasarruf gerektirmelidir.
- Yeni liman açmak yalnızca daha fazla görev değil, yeni kargo ve rota
  fırsatları sunmalıdır.
- Hız geliştirmesi saat başına kazancı artırmalı fakat görevleri anlamsız
  derecede kısaltmamalıdır.
- Kapasite geliştirmesi daha fazla kargoyla daha yüksek ödül sağlamalıdır.
- İleri limanlar daha yüksek toplam görev ödemesi sağlamalı, ancak dakika
  başına kazancı eski kısa rotaları anlamsızlaştıracak kadar artırmamalıdır.
- Oyuncu kötü bir görev seçimi yüzünden kalıcı olarak ilerleyemez duruma
  düşmemelidir.

## 11. Çevrimdışı ilerleme ve kayıt

Görev ilerlemesi kare sayısına değil gerçek zaman damgalarına dayanır. Oyuncu
uygulamayı kapattığında aktif görevler ilerlemeye devam eder. Oyun yeniden
açıldığında geçen zaman uygulanır ve tamamlanmış görevler doğru duruma taşınır.

Bu özellik başlangıç görevlerinin uzun olması gerektiği anlamına gelmez. İlk
görevler bilinçli olarak kısa tutulur; çevrimdışı ilerleme esas değerini orta
ve ileri oyunda kazanır.

Oyun verisi sürümlü JSON olarak otomatik kaydedilir. Para, liman durumları,
gemi sahipliği ve geliştirmeleri, aktif görevler ve öğretici ilerlemesi kayda
dahildir. Oyuncu ayarlar içinden kaydı silip temiz bir oyuna başlayabilir.

Çevrimdışıyken en az bir görev tamamlandıysa oyun açıldığında kompakt bir
“Sen yokken...” özeti gösterilir. Bu pencere tamamlanan sefer sayısını ve bu
seferlerden kazanılan toplam parayı tek yerde gösterir. Hiç görev tamamlanmadıysa
pencere açılmaz; böylece kısa uygulama geçişlerinde oyuncu gereksiz bir onay
adımıyla karşılaşmaz.

## 12. Kontroller ve kullanıcı arayüzü

### 12.1 Temel kontroller

- Gemiye dokunma: Gemiyi seçer ve uygun görevleri hazırlar.
- Filo panelindeki gemiye dokunma: Haritadaki gemiyi seçer ve kamerayı mevcut
  yakınlaştırmayı koruyan kısa, yumuşak bir geçişle gemiye odaklar.
- Görev simgesine dokunma: İlgili limanın tekliflerini açar.
- Limana dokunma: Limanı seçer; kilitliyse açma işlemini gösterir/denenir.
- Boş dünya alanına dokunma: Gemi ve liman vurgularını kaldırır, açık görev
  panelini kapatır.
- Sürükleme ve yakınlaştırma: Büyük dünya haritasında gezinmeyi sağlar. Boş
  denize çift dokunmak, dokunulan noktayı koruyan yumuşak bir geçişle genel ve
  yakın görünüm arasında geçiş yapar; gemi ve liman dokunuşlarını etkilemez.
  Oyuncu manuel yakınlaştırmayla genel görünümden biraz daha uzağa çıkabilir,
  ancak bu hâlâ hareket ettirilebilen normal oynanış kamerasıdır. Bu sınırda
  uzaklaştırmaya devam etmek kamerayı yumuşakça bütün dünyayı ortalayan
  sinematik görünüme geçirir. Sinematik görünüm sürüklenmez; yakınlaştırma,
  çift dokunma veya fare tekerleği oyuncuyu normal kameranın en uzak sınırına
  döndürür. Oyuncu buradan yaklaşmaya kesintisiz biçimde devam edebilir.
- Filo durumu ve gemi satın alma panelleri haritayı kapatmamak için başlangıçta
  kompakt, kapalı sekmeler halinde durur ve başlıklarına dokunularak açılıp
  kapanır. UI dışındaki herhangi bir harita dokunuşu iki paneli de kapatır;
  dokunulan gemi veya limanın normal seçimi devam eder.
- Üstteki Company Level göstergesine dokunmak değer dağılımını ve sonraki
  seviye hedefini gösteren şirket ilerleme panelini açar.

### 12.2 Seçim geri bildirimi

- Seçili gemi kendi siluetini izleyen renkli bir vurgu alır ve `%5` büyür.
- Seçili liman da kendi şekline uygun vurgu alır ve `%5` büyür.
- Boşta geminin sabit duran durum yazısı, görev verilebileceğini belli eden
  hafif bir renk nefesi kullanır; gemi göreve başladığında normal duruma döner.
- Dairesel, nesneden kopuk seçim halkaları kullanılmaz.
- Aynı anda hangi geminin ve limanın seçildiği açıkça anlaşılmalıdır.

### 12.3 Büyük filo kullanılabilirliği

İki gemi mevcut arayüzde anlaşılırdır; daha büyük filolarda okunabilirlik henüz
doğrulanmamıştır. Üç ila altı gemiyle yapılacak kullanılabilirlik testlerinden
sonra filtreleme, sıralama, görevde/boşta gruplama veya kompakt filo görünümü
eklenebilir.

Filo paneli başlığındaki isteğe bağlı `?` düğmesi panelin gemi seçimi ve durum
takibi için kullanıldığını; hız, kapasite ve otomatik görev seçeneklerinin temel
etkilerini kısa, kompakt bir pencerede açıklar. Bu açıklama başlangıç
öğreticisine yeni zorunlu bir adım eklemez.

### 12.4 Başlangıç öğreticisi

Öğreticinin ana yönlendirmesi mevcut üst bilgi alanını kullanır ve sekiz zorunlu
adımdan oluşur: gemi mağazası sekmesini açma, başlangıç gemisini satın alma, CV
göstergesinden Şirket İlerlemesi panelini açma, paneldeki `?` düğmesiyle CV
açıklamasını onaylama, şirket merkezindeki gemiyi seçme, görev işaretli limanı
seçme, ilk görevi kabul etme ve kapanış mesajını onaylama. Her adımda yalnızca
o adımın gerektirdiği ilerleme kontrolü etkin kalır; diğer yönetim panelleri,
harita seçimleri ve görev işlemleri bir önceki adım tamamlanmadan kullanılamaz.

Gemi mağazası başlangıçta kapalıdır ve ilk adımda sekmesi nabız hareketiyle
vurgulanır. Sekme açılınca vurgu satın alma düğmesine geçer. CV açıklaması normal
panel görünümünü kalabalıklaştırmaz; `?` düğmesine dokununca açılan kısa bilgi
penceresinde CV'nin harcanabilir Cash olmadığı, gemi ve liman yatırımlarıyla
artarak şirket seviyelerini ve yeni içerikleri açtığı anlatılır. Oyuncu bu bilgi
penceresini onaylamadan gemi seçme adımına geçemez. Gemi silueti, uygun liman
görev rozetleri ve görev kartları da kendi adımlarında aynı hafif vurgu dilini
kullanır.

İlk görev başladığında “Hazırsın Kaptan!” başlıklı kısa bir kutlama penceresi
açılır. Oyuncu “Denizlere Açıl!” eylemini onayladığında öğretici tamamlanır ve
serbest oyun başlar. Öğretici boyunca görünen “Öğreticiyi Atla” seçeneği de aynı
olumlu “Hazırsın Kaptan!” kapanışını açar; mesaj bu kez oyuncunun başlangıç
parası ve açık limanlarıyla kendi rotasını çizebileceğini belirtir. Oyuncu yine
“Denizlere Açıl!” eylemiyle onay verdikten sonra serbest oyuna geçer. Tamamlanma
veya atlama durumu kayıt verisinde saklanır. Eski kayıtlar öğreticiyi tamamlamış
kabul edilir.

Öğretici tamamlandıktan sonra sol üstte tek satırlık bir “Sonraki Hedef” alanı
ilk oturum ilerlemesini sürdürür. Önce başlangıç seviyesinde açılabilen en ucuz
genişleme limanını ve biriken Cash'i, bu liman açılınca da erişilebilir ilk yeni
gemi modelini ve satın alma ilerlemesini gösterir. İkinci gemi alındığında hedef,
mevcut Company Level ile erişilebilen en erken bölgesel limana döner. Bu liman
açıldığında mevcut seviyede edinilebilen yeni bir gemi uzmanlığı varsa önce bu
yatırımı gösterir. Yeni gemi Company Level eşiğini açtığında hedef sıradaki
bölgesel limanın açma maliyetine dönüşür; uygun yatırım yoksa limanın seviye ve
Company Value eşiği gösterilir. Veri dosyalarında başka genişleme kalmadığında
alan kaybolur. Bu akış kalıcı görev listesine veya yeni bir yönetim sistemine
dönüşmez.

Başlangıç öğreticisi henüz açılmamış ileri sistemleri peşinen anlatmaz. Oyuncu
ilk kez gemi geliştirme ekranına ulaştığında hızın görev süresine, kapasitenin
kargo ve kazanca etkisi; otomasyon açıldığında gereksinimleri ve açık/kapalı oyun
davranışı; ilk orta/uzun görevi başlattığında ise çevrimdışı ilerleme tek bir kısa
bağlamsal açıklamayla gösterilir. Aynı bilgiler daha sonra ilgili paneldeki `?`
düğmesinden yeniden okunabilir.

### 12.5 Ayarlar ve dil

Sağ üstteki ayarlar düğmesi tam ekran bir menü açar ve arka plandaki oyun
etkileşimlerini engeller; gemiler ile görev süreleri akmaya devam eder. Çıkış
onayı açıkken de aynı zaman akışı korunur. Oyuncu ayarlardan oyuna devam
edebilir, ses efektlerini ve arka plan müziğini birbirinden bağımsız açıp
kapatabilir, Türkçe veya İngilizce arayüzü seçebilir ve onay adımından sonra
temiz bir oyuna başlayabilir.

Dil ve ses tercihleri oyun ilerlemesinden ayrı saklanır. Yeni oyuna başlamak
para, filo, liman, görev ve şirket ilerlemesini sıfırlar; seçili dil ile ses
ayarlarını değiştirmez. Henüz müzik veya efekt varlığı bulunmasa da iki ayrı
ses kanalı hazırdır ve ileride eklenecek sesler uygun kanala bağlanacaktır.

## 13. Görsel yön

Görsel stil henüz kesinleşmemiştir. İşlevsel prototip önceliklidir. Korunması
istenen görsel ilkeler şunlardır:

- Büyük kara parçaları ve kıyılara yerleştirilmiş limanlar.
- Karaların çevresini dolaşan okunabilir deniz yolları.
- Hafif kavisli ve rota bazında çeşitlenen kırmızı kesikli çizgiler.
- Küçük ama seçilebilir gemi siluetleri.
- Mobil ekranda haritayı kapatmayan kompakt paneller.
- Görevler için ileride sade ve dikkat çekici ünlem/işaret rozetleri.
- Seçim ve durum renklerinin deniz, kara ve rota renklerinden kolay ayrılması.
- Nihai deniz yüzeyi düşük yoğunlukta, sürekli bir akış veya dalga hareketiyle
  canlı görünmelidir. Limanda bekleyen gemiler bu atmosfere uyumlu çok hafif
  salınım yapabilir; gerçek dünya konumları, dokunma alanları ve yuva düzenleri
  sabit kalmalıdır.

Nihai kara, gemi, liman, görev rozeti ve arayüz varlıkları ayrı bir sanat
yönü çalışmasında belirlenecektir.

## 14. Ses yönü

Ses tasarımı henüz planlama aşamasındadır. Olası ihtiyaçlar:

- Liman ortamı ve hafif deniz ambiyansı.
- Görev kabulü, yükleme, teslimat ve para kazanma geri bildirimleri.
- Gemi motoru ve hareket sesleri.
- Liman açma, gemi satın alma ve geliştirme sesleri.
- Uzun oturumlarda yormayan, kapatılabilir arka plan müziği.

Ses efektleri ve müzik için ayrı açma/kapama tercihleri kullanılır. Böylece
oyuncu görsel/işlevsel geri bildirim seslerini korurken yalnızca müziği veya
tam tersini kapatabilir.

## 15. İçerik hedefleri

Tam sürüm yönü için başlangıç hedefleri:

- Yaklaşık 12 açılabilir liman.
- Birden fazla gemi modeli ve uzmanlık alanı.
- Genel, soğutmalı, dökme yük ve ileride eklenebilecek özel kargo sınıfları.
- Kısa, orta ve uzun görev havuzları.
- Sınırlı ama anlamlı hız ve kapasite geliştirmeleri.
- Erken, orta ve ileri oyun için ayrı ekonomi dengesi.

Yeni liman, gemi veya kargo eklemek kod değişikliği gerektirmemeli; içerikler
veri dosyaları üzerinden tanımlanmalıdır.

## 16. Mevcut prototip durumu

Çalışan ana özellikler:

- Birden fazla gemiye eş zamanlı görev atama.
- Seçili gemiye uygun üç rastgele görev teklifi.
- Yerel ve başka limandan yük alma görevleri.
- Kargo yeteneğine göre görev filtreleme.
- Kavisli tam rota gösterimi ve ilerledikçe kaybolan rota parçaları.
- Yumuşak hareket, dönüş, yükleme ve yanaşma geçişleri.
- Kararlı ve sıkışık liman yuvası düzeni.
- Liman açma, gemi satın alma ve gemi geliştirme ekonomisi.
- Maliyet, seviye ve Company Value katkısını gösteren onaylı liman açma paneli.
- Gelir ile yükleme/boşaltma hızını artıran üç seviyeli liman geliştirmeleri.
- Artan gemi fiyatları ve sınırlı filo/geliştirme seviyeleri.
- Varlık tabanlı Company Value ve kalıcı Company Level ilerlemesi.
- Filo/liman değer dağılımı ve sonraki seviye açılımlarını gösteren ilerleme paneli.
- Sürüm kontrollü JSON kayıt, otomatik kayıt ve kayıt sıfırlama.
- Uygulama kapalıyken görev ilerlemesi.
- Mobil öncelikli yatay kamera ve dokunma etkileşimleri.
- Gemi satın alma, Company Value açıklaması, gemi ve liman seçimi ile görev
  kabulünü sırayla kilitleyip vurgulayan sekiz adımlı öğretici.
- Oyun akışını durdurmayan ayarlar menüsü; bağımsız efekt/müzik kontrolleri.
- Oyun sırasında değiştirilebilen Türkçe ve İngilizce arayüz.

Prototipte bulunan içerik:

- Limanlar: Mersin, İzmir, İstanbul, Antalya, Samsun, Çanakkale, Trabzon, Pire,
  Varna ve Batum.
- Kargolar: Konteyner, Metal, Makine Parçaları, Gıda ve Tahıl.
- Ana gemiler: Başlangıç yük gemisi, soğutmalı yük gemisi ve dökme yük gemisi.

## 17. MVP kabul ölçütleri

İlk oynanabilir sürüm aşağıdakileri sağlamalıdır:

- Yeni oyuncu yardım almadan ilk görevini seçip tamamlayabilmeli.
- Oyuncu ikinci gemiyi satın alabilmeli ve iki görevi paralel yönetebilmeli.
- En az bir kilitli liman para ile açılabilmeli.
- En az iki gemi uzmanlığı ve bunlara bağlı kargo farkı bulunmalı.
- Kayıt kapatıp açıldıktan sonra para, gemiler, limanlar ve görevler doğru
  şekilde geri gelmeli.
- Harita üzerinde gemi, liman ve rota seçimi mobil ekranda anlaşılır olmalı.
- Hiçbir gemi kara üzerinden veya tanımsız bir rota üzerinden geçmemeli.
- Ekonomi, oyuncuyu çok hızlı zenginleştirmemeli veya ilerlemeyi kilitlememeli.

## 18. Açık tasarım kararları

Aşağıdaki konular sonraki test ve tasarım oturumlarında kesinleştirilecektir:

- Nihai görev süreleri ve görev sınıfı eşikleri.
- Nihai ödül eğrisi ve ikinci gemiye ulaşma süresi.
- Nihai Company Value varlık değerleri ve 15 Company Level eşiği.
- İleride ayrı yakıt tankı ve yakıt satın alma akışına ihtiyaç olup olmadığı.
- Nihai filo sınırı ve sınırı artırma yöntemi.
- Liman geliştirme maliyetleri ile gelir/işlem süresi oranlarının nihai dengesi.
- Oyuncu birden fazla gemiye ulaştıktan sonra bakım veya küçük arıza nedeniyle
  gemilerin geçici olarak kullanılamaması değerlendirilecektir. Sistem önce
  reklamsız ve öngörülebilir bir oynanış mekaniği olarak dengelenecek; oyuncuyu
  çalışır gemisiz bırakmayacak ve sonradan reklam izlemeye zorlayan yapay bir
  cezaya dönüştürülmeyecektir.
- 6'dan fazla gemi hedeflenirse büyük filo arayüzü.
- Haritanın kesin ölçeği, kamera sınırları ve bölge açılma sırası.
- Nihai görsel stil, ikon dili, animasyon süresi ve ses yönü.
- Project Harbor'ın ticari gelir üretmesi hedeflenir. Oyuncunun isteyerek
  izlediği ödüllü reklamlar ve düşük fiyatlı uygulama içi satın alımlar öncelikli
  adaylardır; ödül miktarları, sıklık ve kesin model temel ekonomi
  dengelendikten sonra kararlaştırılacaktır.

## 19. Tasarım dışı kapsam

Şu aşamada planlanmayan veya öncelikli olmayan özellikler:

- Çok oyunculu mod.
- Gerçek zamanlı oyuncular arası ticaret.
- Gerçekçi denizcilik simülasyonu veya ayrıntılı gemi kullanımı.
- Oyuncunun gemiyi manuel olarak sürmesi.
- Tamamen gerçek dünya ölçeğinde rota ve süre simülasyonu.
- Gemi geliştirmesi için zorunlu tersane dönüşleri ve refit yolculukları.

Project Harbor'ın odağı, kolay dokunmatik kontrolle yönetilen, görsel olarak
tatmin edici ve giderek büyüyen bir liman-taşımacılık ağıdır.
