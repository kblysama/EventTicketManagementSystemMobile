# Yerin Mobil

Flutter ile Android ve iOS için etkinlik, demo bilet satın alma ve check-in uygulaması. Katılımcı, organizer ve admin akışları aynı Laravel API ve Reverb sunucusunu kullanır.

## Gereksinimler

- Flutter **3.47.4** (`.flutter-version` ve `.fvmrc`); bağımlılıklar `pubspec.lock` ile sabittir.
- Android SDK ve Java 17+; Android emülatörü veya USB hata ayıklaması açık cihaz.
- iOS için macOS, Xcode ve imzalama hesabı. Windows üzerinde iOS cihaz kabulü yapılamaz.
- Yan dizindeki `event-ticket-management-system` backend’i; PostgreSQL, Redis, Laravel ve Reverb.

## Başlatma

```powershell
# Backend dizininde; mevcut veritabanı/volume silinmez.
docker compose up -d

# Mobil dizinde
flutter pub get
Copy-Item config/android-emulator.example.json config/local.json
# config/local.json: backend public REVERB_APP_KEY değerini gir.
flutter run --dart-define-from-file=config/local.json
```

Bu çalışma alanında SDK `.tools/flutter/bin/flutter.bat` konumundadır. Windows'ta Türkçe/uzun klasör yolu Flutter shader ve Android araçlarını etkileyebilir. Projeyi taşımadan kullanılabilecek eşleme:

```powershell
subst Y: "$PWD"
Set-Location Y:/
.tools/flutter/bin/flutter.bat pub get
.tools/flutter/bin/flutter.bat run --dart-define-from-file=config/local.json
```

Y: önceden kullanılıyorsa boş bir sürücü harfi seç. Eşleme oturum/restart sonrası yeniden gerekebilir. Android için `android.overridePathCheck=true` bu dizinin derlenmesini sağlar. SDK'yı değiştirmek yerine önce bu yolu kullan.

## Ortam ayarları

- Android emülatörü: API `http://10.0.2.2:8000/api`, Reverb `10.0.2.2:8080`.
- iOS simülatörü ve Mac üzerindeki backend: `localhost`; örnek `config/ios-simulator.example.json`.
- Fiziksel cihaz: erişilebilir backend adresi, tercihen HTTPS/WSS; örnek `config/device.example.json`. Bilgisayarın `localhost` adresi telefona ait değildir.
- Backend `APP_URL`, kapak görselleri için cihazdan erişilebilir bir adres üretmelidir.
- HTTP Android debug derlemesinde açıktır. Release dağıtımlarında HTTPS/WSS kullan.
- `REVERB_APP_KEY` public değerdir; Reverb secret, token, şifre veya `.env` dosyası uygulama varlıklarına eklenmez. `config/local.json` Git dışında tutulur.

## Uygulama yapısı

- `lib/core`: API, typed JSON modelleri, tema/bileşenler, router ve realtime.
- `lib/features/auth`: kayıt/giriş, güvenli token saklama, şifre yenileme ve hesap.
- `lib/features/discovery`, `orders`, `tickets`: keşif, demo satın alma, QR bilet ve siparişler.
- `lib/features/organizer`, `check_in`, `admin`: etkinlik/bilet tipi yönetimi, doğrulama ve salt okunur admin.
- `yerin-mobil-ui`: değiştirilmeyen 23 tasarım kaynağı. `assets/images/yerin-logo.png` sağlanan logodur; Manrope lisansı `assets/fonts/OFL.txt` içindedir.

[API sözleşmesi](docs/API.md) rota, JSON, hata ve realtime davranışlarını açıklar. [Uygulama durumu](docs/IMPLEMENTATION_STATUS.md) yapılanları ve gerçek cihaz kabulünün sınırlarını takip eder.

## Kontroller

```powershell
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/local.json
# macOS üzerinde:
flutter build ios --simulator --debug --dart-define-from-file=config/local.json
```

Windows'ta Flutter analiz sunucusu yol hatası verirse `dart analyze lib test integration_test` kullan. Golden testleri Windows referanslarıdır; diğer platformlarda font rasterizasyonu farklı olabilir. Golden yenileme yalnızca incelenen görsel değişikliklerde yapılır: `flutter test test/screens_test.dart --update-goldens`.

APK çıktısı: `build/app/outputs/flutter-apk/app-debug.apk`. Gerçek ödeme ve mağaza yayını bu teslimin kapsamı dışındadır. Windows platform klasörü mevcut çalışma alanında korunmuştur; mobil kabulünün parçası değildir.

## Şifre bağlantısı

Web sıfırlama sayfasındaki “Uygulamada aç” bağlantısı `yerin://reset-password?token=...&email=...` biçimindedir. Uygulama yalnızca beklenen scheme/host ve dolu alanları kabul eder. Web üzerinden şifre yenileme çalışmaya devam eder.

## Kabul senaryosu

Katılımcı kaydı/girişi → etkinlik seçimi → demo satın alma → her biletin QR kodunu açma → organizer ile aynı etkinlikte doğrulama → ikinci doğrulamada kullanılmış uyarısı → admin sipariş görünümü. Web ve mobil açıkken fiyat/kapasite, etkinlik, sipariş ve check-in değişikliklerini; ardından ağ kesilip geri geldiğinde yenilemeyi kontrol et. Kamera izni reddinde manuel kod girişi çalışmalıdır.
