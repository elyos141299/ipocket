# iPocket — Struktur & Rencana Build

Aplikasi Flutter "iPocket": panel status untuk MiFi Advan iPocket MF01
(ZTE goform) — pantau sinyal, baterai, perangkat terhubung, dan SMS
tanpa membuka browser. Spesifikasi API: `../API-CONTRACT.md`.

## Struktur proyek

```
app/
├── pubspec.yaml            # package: ipocket; deps: flutter, http, crypto
├── analysis_options.yaml
├── IOS-NOTES.md            # potongan Info.plist wajib + bundle id
├── README-BUILD.md         # file ini
└── lib/
    ├── main.dart           # MaterialApp "iPocket" → AppShell
    ├── app_state.dart      # state bersama (gateway, password, sesi) —
    │                       # hanya di memori, tidak disimpan permanen
    ├── zte_client.dart     # klien goform: Referer, cookie jar, login
    │                       # Gen B (LD/RD + SHA-256) → fallback Gen A
    │                       # (base64), status gabungan, SMS, log
    ├── models.dart         # DeviceStatus (parse longgar, anti-crash) +
    │                       # SmsMessage + decode hex UTF-16BE
    └── screens/
        ├── app_shell.dart        # AppBar + navigasi bawah 4 tab
        ├── status_screen.dart    # panel koneksi (password) + status
        ├── sms_screen.dart       # daftar SMS / fallback mentah
        ├── diagnostics_screen.dart # log request mentah + Tes Lengkap
        └── settings_screen.dart  # satu field gateway
```

Tab Diagnostik adalah alat verifikasi v0: tombol **Jalankan Tes
Lengkap** menjalankan urutan LD/RD → login Gen B → login Gen A →
status gabungan → SMS, dan semua request/respons mentah tercatat untuk
di-screenshot dan dicocokkan dengan perangkat asli.

## Build lokal (butuh Mac untuk iOS)

```bash
flutter pub get
flutter run            # ke perangkat yang terhubung ke WiFi MiFi
flutter build ios --release   # butuh Xcode + signing
```

## Rencana build .ipa via GitHub Actions macOS (BELUM dibuat)

Workflow `.github/workflows/build-ios.yml` — rencana tertulis saja,
file workflow-nya belum ditulis. Garis besarnya:

1. Trigger: `workflow_dispatch` (manual) dan/atau push tag `v*`.
2. Runner: `macos-latest` (menyediakan Xcode untuk build iOS).
3. Setup Flutter stable (mis. `subosito/flutter-action@v2`).
4. `flutter pub get`.
5. Sisipkan potongan `Info.plist` dari `IOS-NOTES.md` ke
   `ios/Runner/Info.plist` (langkah skrip kecil di CI, atau commit
   Info.plist yang sudah dilengkapi saat folder `ios/` dibuat dengan
   `flutter create`).
6. Build tanpa tanda tangan untuk sideload:
   `flutter build ipa --no-codesign`
   (alternatif: `flutter build ios --release --no-codesign` lalu
   bungkus `Payload/*.app` menjadi `.ipa` secara manual).
7. Upload hasil `.ipa` sebagai artifact workflow.
8. Di iPhone: install `.ipa` lewat AltStore/SideStore dengan Apple ID
   biasa (provisioning gratis, bundle id `id.oroboo.ipocket`).

Catatan: build Android (`flutter build apk --release`) bisa ditambah
di job terpisah runner Ubuntu bila nanti dibutuhkan — di luar rencana
v0 yang fokus iPhone untuk tes sideload.
