# Aile Planı (Android)

Ailece kullanılan yaşam koçu ve planlama uygulaması. Herkes kendi telefonundan
kendi hesabıyla girer; aynı aileye katılan herkes aynı planı canlı görür.

## Menüler

| Sekme | Ne var |
|---|---|
| **Bugün** | Koçun önerisi, bugünün programı ve planları, bugünün alışkanlıkları, önümüzdeki 7 gün, dilek kutusu ve bu ayın bütçesi |
| **Program** | Tekrar eden haftalık program (iş, tarla, aile, çocuklar, eşimle, kendime). Her günün dağılımı renkli çubukla görünür |
| **Planlar** | Kısa vadeli planlar (piknik, sinema, ziyaret), uzun vadeli hedefler (tatil, ev, eğitim) ve yapılanlar. Hedeflere birikim eklenir, "ayda ne kadar ayırmalı" hesaplanır |
| **Bütçe** | Aylık aile bütçesi, harcanan/kalan, kişilere ve kategorilere göre dağılım, uzun vadeli birikimler |
| **Aile** | Dilek kutusu, alışkanlıklar (seri takibi), denge raporu, hatırlatmalar, aile ayarları |

- **Dilek kutusu:** Eş ve çocuklar istediklerini yazar; tek dokunuşla tarihli plana dönüşür.
- **Denge raporu:** Haftalık programdan kime ne kadar vakit, bu ay kime ne kadar bütçe ayrıldığını gösterir; koç önerileri buradan çıkar.
- **Hatırlatmalar:** Telefona özel günlük hatırlatmalar, sabah "günün programı" özeti ve yeni dilek bildirimi (arka planda ~15 dakikada bir kontrol edilir).

## Aile

- İlk giren kişi **"Aileyi kur"** der; eşinin ve çocuklarının adlarını yazar.
- **Aile → Aile ayarları → Davet kodu** eşine ve büyük çocuklara gönderilir.
- Onlar uygulamayı kurar, hesap açar, **"Kodla katıl"** deyip kodu yazar ve listeden kendilerini seçer.
- Telefonu olmayan çocuklar yalnızca "kişi" olarak eklenir; planlarda ve dileklerde seçilebilir.

## Teknik

- Flutter + Firebase (Auth + Firestore). Firebase projesi: **`aile-plani`**.
  Ayarlar `lib/firebase_options.dart` dosyasındadır.
- `firestore.rules` değişince Firebase Console'da **aile-plani** projesinde
  Firestore → Kurallar'a dosyanın tamamını yapıştırıp **Yayınla** deyin.
- `main` dalına her gönderimde GitHub Actions APK derler ve **Releases**
  bölümüne koyar. Kurulu uygulama yeni sürümü kendisi bulup günceller.
- İmza: uygulamanın kendi anahtarı (`ci/aile-plani.p12`). Şifresi depo
  ayarlarında `AILE_KEYSTORE_PASSWORD` gizli değişkenindedir. Bu şifre
  kaybolursa telefondaki uygulama güncellenemez, bir yere not edin.
