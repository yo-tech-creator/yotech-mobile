# Cleanup Talimatları

## Gereksiz Dosyaları Temizle

### `.deleted` Klasörü
`.deleted` klasörü eski batch dosyalarını içerir ve silinebilir:

```bash
# Windows
rmdir /s /q .deleted

# macOS/Linux
rm -rf .deleted
```

### IDE Cache Dosyaları
`.idea` ve `.qodo` klasörleri IDE cache'leridir ve `.gitignore`'da olmalıdır:

```bash
# Windows
rmdir /s /q .idea
rmdir /s /q .qodo

# macOS/Linux
rm -rf .idea
rm -rf .qodo
```

## Kontrol Listesi

- [ ] `.deleted` klasörü silindi
- [ ] `.idea` klasörü silindi (varsa)
- [ ] `.qodo` klasörü silindi (varsa)
- [ ] `.gitignore` güncellenmiş
- [ ] `flutter clean` çalıştırıldı
- [ ] `flutter pub get` çalıştırıldı

## Sonrası

Tüm temizlik işlemlerinden sonra:

```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```
