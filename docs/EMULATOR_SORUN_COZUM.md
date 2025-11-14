# 🔧 Android Emülatör Sorun Çözümleri

## ⚠️ "Android emulator exited with code 1" Hatası

Bu hata genellikle şu nedenlerden kaynaklanır:

---

## ✅ ÇÖZÜM 1: Android Studio'dan Yeni Emülatör Oluştur

### Adım Adım:

1. **Android Studio'yu aç**

2. **Tools → Device Manager**

3. **Mevcut emülatörü sil:**
   - `Pixel_6_API_34_yeni` üzerine sağ tık
   - **Delete** seç

4. **Yeni emülatör oluştur:**
   - **Create Device** butonuna tıkla
   - **Phone** → **Pixel 6** seç → **Next**
   - **Release Name:** `Tiramisu` (API 33) veya `UpsideDownCake` (API 34) seç
   - **Download** butonuna tıkla (eğer indirilmemişse)
   - İndikten sonra **Next**
   - **AVD Name:** `Pixel_6_API_33` yaz
   - **Advanced Settings**:
     - RAM: **2048 MB** (minimum)
     - VM Heap: **256 MB**
     - Internal Storage: **2048 MB**
     - SD Card: **512 MB**
   - **Finish**

5. **Emülatörü test et:**
   - Yeni emülatör listede görünecek
   - ▶️ butonuna tıkla
   - Emülatör açılmalı (30-60 saniye)

---

## ✅ ÇÖZÜM 2: Hypervisor Kontrolü

### Windows Hyper-V veya WHPX:

1. **Virtualization kontrol:**
   ```cmd
   systeminfo | findstr /C:"Virtualization"
   ```
   **Sonuç:** `Virtualization Enabled In Firmware: Yes` olmalı

2. **BIOS'ta Virtualization aktif değilse:**
   - Bilgisayarı yeniden başlat
   - BIOS'a gir (F2, F10, Delete tuşları)
   - **Virtualization Technology** veya **Intel VT-x / AMD-V** bul
   - **Enabled** yap
   - Kaydet ve çık

3. **Windows Hyper-V:**
   - **Denetim Masası** → **Programlar** → **Windows özelliklerini aç veya kapat**
   - **Hyper-V** işaretle
   - **Tamam** → Yeniden başlat

**VEYA**

   - **Windows Hypervisor Platform** işaretle (Hyper-V yerine)

---

## ✅ ÇÖZÜM 3: HAXM Kurulumu (Intel işlemciler için)

**Not:** Yalnızca **Hyper-V kapalıysa** çalışır!

1. **HAXM indir:**
   - https://github.com/intel/haxm/releases
   - En son sürümü indir (örn: haxm-windows_v7_8_0.zip)

2. **Kur:**
   - Zip'i aç
   - `intelhaxm-android.exe` çalıştır
   - **RAM:** 2048 MB ayarla
   - **Install**

3. **Test:**
   ```cmd
   sc query intelhaxm
   ```
   **Sonuç:** `STATE: 4 RUNNING` olmalı

---

## ✅ ÇÖZÜM 4: Emülatör Ayarlarını Optimize Et

### Android Studio → Device Manager → Emülatör Ayarları:

1. **Graphics:** `Software` yerine `Hardware - GLES 2.0` dene

2. **Boot Option:** `Quick Boot` seç

3. **RAM:** Minimum 2048 MB

4. **Multi-Core CPU:** CPU çekirdek sayısının yarısı kadar

---

## ✅ ÇÖZÜM 5: Android SDK Yollarını Kontrol

```cmd
flutter doctor -v
```

**Bakılması Gerekenler:**
- ✅ Android SDK yüklü mü?
- ✅ Android SDK Command-line Tools yüklü mü?
- ✅ Platform-tools yüklü mü?

**Eksikse:**
- Android Studio → SDK Manager
- **Android SDK Command-line Tools (latest)** işaretle
- **Apply** → **OK**

---

## ✅ ÇÖZÜM 6: Farklı API Level Dene

**API 34 sorunluysa:**
- API 33 (Android 13) dene
- API 30 (Android 11) dene
- API 29 (Android 10) daha stabil olabilir

---

## 📱 Test Komutu

Emülatör çalıştıktan sonra:

```bash
# Cihazları listele
flutter devices

# Görünmelidir:
# sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64 • Android 14 (API 34) (emulator)

# Uygulamayı çalıştır
flutter run
```

---

## 🚀 Alternatif: Chrome ile Devam Et

Emülatör sorunlarıyla uğraşmak istemiyorsan:

```bash
flutter run -d chrome
```

**Avantajları:**
- ✅ Anında başlar
- ✅ RAM az kullanır
- ✅ Hot reload çok hızlı
- ✅ Login ve UI testleri yapılabilir

**Dezavantajı:**
- ❌ Mobil-specific özellikler test edilemez

---

## 📊 Öncelik Sırası

1. 🥇 **Chrome kullan** (şimdilik en kolay)
2. 🥈 **Yeni emülatör oluştur** (Android Studio'dan)
3. 🥉 **Hypervisor düzelt** (gerekirse)
4. 🏅 **Fiziksel cihaz bağla** (en stabil)

---

## 💡 Önerim

**Login ve UI testleri için:**
→ Chrome yeterli

**Mobil özellikleri test için:**
→ Fiziksel Android cihaz (en stabil)

**Emülatör:**
→ Sonra düzeltebilirsin

---

**Hazırlayan:** Claude AI  
**Tarih:** 30 Ekim 2025
