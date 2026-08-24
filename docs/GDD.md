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

Yeni satın alınan gemiler şirket merkezinin teslimat iskelesinde görünür ve
ayrılmış liman yuvasına kısa bir tanıtım hareketiyle geçer. Oyuncu ilk gemisini
öğreticinin ilk adımında satın alır; gemi şirket merkezinde görünerek aynı
teslimat akışını izler. Bu yalnızca görsel bir teslimat akışıdır; oyuncuya ek
işlem veya bekleme yüklemez.

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
- Uzun vadeli hedef: 15–20 limanlık bir ağ ve farklı görevlere uygun,
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
- İstanbul kilitlidir.
- Antalya, Şirket Seviyesi 3; Samsun ise Şirket Seviyesi 4 genişleme
  hedefi olarak kilitlidir.
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

Tam sürüm için yaklaşık 15–20 açılabilir liman hedeflenir. Dünya, büyük kara
parçalarından ve bunların kıyılarındaki limanlardan oluşur. Gemiler karaların
içinden geçemez; tanımlı deniz koridorlarını ve kıvrımlı rotaları izler.

Harita ilk bölgedeki limanları yakın ve anlaşılır tutmalı, yeni bölgeler
açıldıkça mesafeleri ve rota karmaşıklığını kademeli artırmalıdır.
İlk bölgesel ağ Türkiye kıyılarındaki limanlarla büyür; daha sonraki uzak bölge
genişlemelerinde yabancı limanlar kullanılarak yeni bir ölçek duygusu yaratılır.

İlk prototip genişlemesinde Antalya `1.500 ₺` karşılığında `800 CV`, Samsun
ise `2.600 ₺` karşılığında `1.200 CV` şirket varlığı kazandırır. Bu değerler
nihai ekonomi dengesi değildir; seviye ve bölge akışını test etmek içindir.

## 6. Limanlar

Her limanın şu temel özellikleri vardır:

- Benzersiz kimlik ve görünen ad.
- Dünya üzerindeki konum.
- Kilit durumu ve açma maliyeti.
- Seviye ve ileride kullanılacak geliştirme maliyetleri.
- Ödül çarpanı.
- Birden fazla gemi için tanımlı yanaşma yuvaları.
- Bağlı olduğu deniz rotaları.

Kilitli limana dokunulduğunda doğrudan para harcanmaz. Önce limanın açıklamasını,
açma bedelini, gereken ve mevcut Şirket Seviyesini, mevcut kasayı ve sağlayacağı
Company Value katkısını gösteren kompakt bir onay paneli açılır. Koşullar
sağlanmıyorsa açma düğmesi eksik para veya seviye nedenini göstererek devre dışı
kalır. Liman yalnızca oyuncu etkin açma düğmesine dokunduğunda satın alınır.
Açık limana dokunmak, seçili gemi varsa o limandaki uygun görev tekliflerini
gösterir.

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

Aynı modelden alınan her yeni gemi bir öncekinden daha pahalıdır. Mevcut
prototip formülü taban fiyatı her sahip olunan gemi için `1,6` katsayısıyla
büyütür ve fiyatı en yakın 10'a yuvarlar.

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

## 8. Görev sistemi

### 8.1 Teklif üretimi

- Görevler rastgele oluşturulur.
- Seçili ve boşta olan her gemi için aynı anda üç teklif sunulur.
- Teklifler yalnızca geminin taşıyabildiği kargolardan üretilir.
- Yükleme ve teslimat limanı aynı olamaz.
- Görev, geminin bulunduğu limandan başlamak zorunda değildir.
- Aynı içeriğe sahip teklifler arayüzde ayrı ayrı tekrarlanmaz.
- Kilidi açılmamış limanlar normal görev havuzunda yer almaz.

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

Prototipte yolculuk ve liman süreleri testleri hızlandırmak amacıyla bilerek
çok kısadır. Bu sayılar nihai denge değildir.

## 9. Rota, hareket ve liman animasyonları

- Deniz rotaları hafif kavisli ve birbirinden farklı biçimlerde olmalıdır.
- Bütün kayıtlı rotaların yumuşatılmış merkez çizgileri, geliştirme testlerinde
  tüm kara poligonlarına karşı otomatik olarak doğrulanır.
- Tam görev rotası kırmızı, kesikli bir çizgiyle gösterilir.
- Gemi ilerledikçe geçtiği çizgi parçaları kaybolur; ilerideki parçalar yerinde
  kalır ve gemiye doğru kaymaz.
- Geminin burnu hareket ettiği rotanın teğetine hizalanır.
- Yuvadan çıkış, yük limanına giriş ve teslimat limanına yanaşma ani açı
  değişimleri olmadan yumuşak yapılır.
- Başka limana yük almaya giden gemi mevcut liman merkezine uğramaz.
- Yükleme limanına ulaşan gemi yuvaya oturmadan liman merkezinde bekler ve
  ardından teslimat rotasına devam eder.
- Teslimattan sonra gemi ayrılmış boş yuvaya yumuşakça yerleşir.

## 10. Ekonomi

### 10.1 Gelir

Görev ödülü şu girdilerden oluşur:

- Kargonun temel değeri.
- Yükleme ile teslimat arasındaki mesafe.
- Kargo miktarı.
- Yükleme ve teslimat limanlarının seviye çarpanları.

Mevcut erken oyun ödülleri, 750 TL'lik ilk limana 3–4 görevde ve ardından 800
TL'lik ikinci gemiye sonraki 3–4 görevde ulaşılacak şekilde korunur. Nihai görev
süreleri ve sefer masrafı oranları mobil oynanış testlerinde birlikte yeniden
değerlendirilir.

### 10.2 Giderler

Mevcut çalışan giderler:

- Yeni liman açma.
- Yeni gemi satın alma.
- Gemi hızını geliştirme.
- Gemi kapasitesini geliştirme.
- Görevin yükleme ve teslimat ayaklarının toplam mesafesiyle geminin tüketim
  oranına bağlı sefer masrafı.

Görev kartında brüt ödül, sefer masrafı ve net kazanç kabulden önce gösterilir.
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
- Filo panelindeki gemiye dokunma: Haritadaki gemiyi seçmekle aynı sonucu verir.
- Görev simgesine dokunma: İlgili limanın tekliflerini açar.
- Limana dokunma: Limanı seçer; kilitliyse açma işlemini gösterir/denenir.
- Boş dünya alanına dokunma: Gemi ve liman vurgularını kaldırır, açık görev
  panelini kapatır.
- Sürükleme ve yakınlaştırma: Büyük dünya haritasında gezinmeyi sağlar. Boş
  denize çift dokunmak, dokunulan noktayı koruyan yumuşak bir geçişle genel ve
  yakın görünüm arasında geçiş yapar; gemi ve liman dokunuşlarını etkilemez.
- Filo durumu ve gemi satın alma panelleri haritayı kapatmamak için başlangıçta
  kompakt, kapalı sekmeler halinde durur ve başlıklarına dokunularak açılıp
  kapanır. UI dışındaki herhangi bir harita dokunuşu iki paneli de kapatır;
  dokunulan gemi veya limanın normal seçimi devam eder.
- Üstteki Company Level göstergesine dokunmak değer dağılımını ve sonraki
  seviye hedefini gösteren şirket ilerleme panelini açar.

### 12.2 Seçim geri bildirimi

- Seçili gemi kendi siluetini izleyen renkli bir vurgu alır ve `%5` büyür.
- Seçili liman da kendi şekline uygun vurgu alır ve `%5` büyür.
- Dairesel, nesneden kopuk seçim halkaları kullanılmaz.
- Aynı anda hangi geminin ve limanın seçildiği açıkça anlaşılmalıdır.

### 12.3 Büyük filo kullanılabilirliği

İki gemi mevcut arayüzde anlaşılırdır; daha büyük filolarda okunabilirlik henüz
doğrulanmamıştır. Üç ila altı gemiyle yapılacak kullanılabilirlik testlerinden
sonra filtreleme, sıralama, görevde/boşta gruplama veya kompakt filo görünümü
eklenebilir.

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

- 15–20 açılabilir liman.
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
- Artan gemi fiyatları ve sınırlı filo/geliştirme seviyeleri.
- Varlık tabanlı Company Value ve kalıcı Company Level ilerlemesi.
- Filo/liman değer dağılımı ve sonraki seviye açılımlarını gösteren ilerleme paneli.
- Sürüm kontrollü JSON kayıt, otomatik kayıt ve kayıt sıfırlama.
- Uygulama kapalıyken görev ilerlemesi.
- Mobil öncelikli yatay kamera ve dokunma etkileşimleri.
- Gemi satın alma, Company Value açıklaması, gemi ve liman seçimi ile görev
  kabulünü sırayla kilitleyip vurgulayan sekiz adımlı öğretici.
- Oyunu duraklatan ayarlar menüsü; bağımsız efekt/müzik kontrolleri.
- Oyun sırasında değiştirilebilen Türkçe ve İngilizce arayüz.

Prototipte bulunan içerik:

- Limanlar: Mersin, İzmir, İstanbul, Antalya, Samsun, Çanakkale ve Trabzon.
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
- Liman seviyelerinin görev, yükleme hızı ve gelir üzerindeki etkileri.
- Oyuncu birden fazla gemiye ulaştıktan sonra bakım veya küçük arıza nedeniyle
  gemilerin geçici olarak kullanılamaması değerlendirilecektir. Sistem önce
  reklamsız ve öngörülebilir bir oynanış mekaniği olarak dengelenecek; oyuncuyu
  çalışır gemisiz bırakmayacak ve sonradan reklam izlemeye zorlayan yapay bir
  cezaya dönüştürülmeyecektir.
- 6'dan fazla gemi hedeflenirse büyük filo arayüzü.
- Mobil UX turunda filo paneli başlığına, panelin amacını kısa ve kompakt bir
  açıklamayla anlatan isteğe bağlı `?` yardım düğmesi değerlendirilmelidir.
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
