# iPocket — Struktur & Rencana Build

Aplikasi Flutter "iPocket": panel status untuk MiFi Advan iPocket MF01
(ZTE goform) — pantau sinyal, baterai, perangkat terhubung, dan SMS
tanpa membuka browser. Spesifikasi API: `../API-CONTRACT.md`.

Versi: **v0.4** — penemuan API final (ambil com/set/lib/sim_device/
net/wifi). v0.2 membuktikan firmware perangkat menjawab 404 untuk
/goform/* dan WebUI-nya RequireJS + Knockout yang modul aplikasinya
dimuat dinamis; v0.3 memetakan tag `<script>` index.html, mencoba
kamus path modul umum, dan men-crawl nama modul require/define —
hasilnya js/main.js terbaca dan membocorkan peta require.config:
"service" → `com`, SIM/SMS → `sim_device`, jaringan → `net`, WiFi →
`wifi`, plus petunjuk file `set` dan `lib`. v0.4 mengambil persis
enam file layanan itu (`js/com.js`, `js/set.js`, `js/lib.js`,
`js/sim_device.js`, `js/net.js`, `js/wifi.js`), memindai kandidat
endpoint + konteks kata kunci pemanggilan API di dalamnya, dan
mencatat isi `set.js` secara utuh bila kecil; lihat
`lib/discovery.dart`.

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
    ├── discovery.dart      # v0.2: penemuan API — unduh HTML + file JS
    │                       # WebUI dari perangkat, pindai kandidat
    │                       # endpoint & konteks panggilan AJAX/fetch
    │                       # v0.3: penemuan lanjutan — tag <script>
    │                       # verbatim, kamus modul, crawl require/
    │                       # define + paths:, pindaian kata kunci
    │                       # khusus (goform/cmd_process/.cgi/proc_*)
    │                       # v0.4: penemuan final — ambil 6 file
    │                       # layanan (com/set/lib/sim_device/net/
    │                       # wifi), konteks ajax/cgi/api/cmd/url,
    │                       # isi set.js utuh bila < 12000 byte
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
di-screenshot dan dicocokkan dengan perangkat asli. Tombol kedua,
**Jalankan Penemuan API** (v0.2), membaca HTML + file JS WebUI dari
perangkat dan mencatat kandidat endpoint asli beserta konteks
pemanggilannya ke log yang sama. Tombol ketiga, **Penemuan API
Lanjutan** (v0.3), memburu modul aplikasi RequireJS yang dimuat
dinamis: mencatat semua tag `<script>` index.html secara verbatim,
mencoba kamus path modul (`js/main.js`, `js/service.js`, dst. —
status 404 pun dicatat sebagai informasi layout), lalu mengekstrak
nama modul dari `require([...])`/`define([...])` dan nilai `paths:`
dari require.config untuk mengunduh file JS aplikasi dan
memindainya, termasuk pindaian khusus kata kunci `goform`,
`cmd_process`, `.cgi`, `proc_get`, `proc_post`. Tombol keempat,
**Penemuan API Final** (v0.4), mengambil enam file layanan yang
terpetakan dari peta require.config di js/main.js — `js/com.js`,
`js/set.js`, `js/lib.js`, `js/sim_device.js`, `js/net.js`,
`js/wifi.js` — lalu memindai kandidat endpoint dan konteks kata
kunci pemanggilan API (`ajax`, `cgi`, `api`, `goform`, `cmd`,
`method`, `action`, `url`; anggaran konteks lebih besar untuk
com.js dan lib.js), dan mencatat isi `set.js` secara utuh bila
ukurannya di bawah 12000 byte karena file konstanta itu menentukan
awalan path API.

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
