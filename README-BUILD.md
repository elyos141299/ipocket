# iPocket — Struktur & Rencana Build

Aplikasi Flutter "iPocket": panel status untuk MiFi Advan iPocket MF01
(API reqproc perangkat) — pantau sinyal, baterai, perangkat terhubung,
dan SMS tanpa membuka browser. Spesifikasi API: `../API-CONTRACT.md`.

Versi: **v1.0** — APLIKASI BENERAN: klien reqproc + dashboard
referensi + SMS baca. Riwayat singkat: v0.2 membuktikan firmware
perangkat menjawab 404 untuk /goform/*; penemuan bertingkat
(v0.2–v0.4, aplikasi membaca JS WebUI dari perangkat: index →
main.js → com.js 211 KB) menemukan gerbang asli perangkat:
**GET /reqproc/proc_get (cmd=…, multi_data=1)** dan
**POST /reqproc/proc_post (goformId=…)** — kosakata cmd/goformId
gaya ZTE, tapi path reqproc (server GoAhead). Login: POST LOGIN
dengan sandi Base64 (PASSWORD_ENCODE=true di set.js); result
"0"/"4" sukses, "3" sandi salah, "2" pengguna ganda. v1.0 memakai
klien baru `lib/reqproc_client.dart` (login terstruktur, status
gabungan persis daftar cmd WebUI, sms_data_total,
sms_capacity_info); `lib/zte_client.dart` lama sudah dihapus.
Tab Status menjadi dashboard ala `../UI-REFERENCE.md` (tema biru
muda): kartu sambutan + login, header operator/jaringan/sinyal,
lingkaran pemakaian data bulanan, kecepatan live, 4 tile
(Battery/SMS/Clients/SD Sharing), dan detail label-nilai, dengan
auto-refresh 15 detik selama tab tampil & sudah login. Tab SMS
menampilkan daftar asli (baca-saja; kirim & hapus menyusul).
Tab Diagnostik & Pengaturan dipertahankan apa adanya — semua
tombol tes/penemuan masih dipakai untuk verifikasi lapangan,
dan Tes Lengkap sekarang berjalan di atas reqproc.

Asumsi tampilan lingkaran data: perangkat user TIDAK mengatur
batas data (Manajemen Data "Tidak diatur"), jadi ring digambar
proporsional terhadap **patokan tampilan 10 GB** — angka di tengah
lingkaran selalu total pemakaian bulan ini yang sebenarnya dari
`data_counter` (monthlySent + monthlyReceived); patokan hanya
mengatur seberapa penuh ring-nya.

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
    ├── reqproc_client.dart # klien reqproc (v1.0): Referer, cookie
    │                       # jar, login LOGIN sandi Base64 (hasil
    │                       # terstruktur), status gabungan, SMS +
    │                       # kapasitas, Tes Lengkap reqproc; juga
    │                       # rumah DiagEntry/DiagnosticsLog bersama
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
    ├── models.dart         # DeviceStatus reqproc (parse toleran:
    │                       # baterai %, sinyal per jenis jaringan,
    │                       # data_counter Map/string, station_list
    │                       # List/string) + SmsCapacity + SmsMessage
    │                       # + decode hex UTF-16BE
    └── screens/
        ├── app_shell.dart        # AppBar + navigasi bawah 4 tab
        ├── status_screen.dart    # dashboard: sambutan+login, header,
        │                       # lingkaran data bulanan, 4 tile,
        │                       # detail, auto-refresh 15 detik
        ├── sms_screen.dart       # daftar SMS asli + kapasitas
        │                       # (baca-saja)
        ├── diagnostics_screen.dart # log request mentah + Tes Lengkap
        └── settings_screen.dart  # satu field gateway
```

Tab Diagnostik adalah alat verifikasi lapangan: tombol **Jalankan
Tes Lengkap** sekarang menjalankan urutan reqproc (login → status
gabungan → daftar SMS → kapasitas SMS), dan semua request/respons
mentah tercatat untuk di-screenshot dan dicocokkan dengan perangkat
asli. Tombol kedua,
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
