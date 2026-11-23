# iPocket — Struktur & Rencana Build

Aplikasi Flutter "iPocket": panel status untuk MiFi Advan iPocket MF01
(API reqproc perangkat) — pantau sinyal, baterai, perangkat terhubung,
dan SMS tanpa membuka browser. Spesifikasi API: `../API-CONTRACT.md`.

Versi: **v1.2** — tema Advan ter-push, dashboard tuntas,
Gelombang A (SMS penuh + sambung/putus + reboot + ganti sandi),
ikon aplikasi siap tanam.
Riwayat singkat: v0.2 membuktikan firmware
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

**v1.1** (dari uji perangkat asli v1.0, 23 Nov 2026 — login,
status, dan SMS TERBUKTI jalan; tetapi `data_counter`,
`station_list`, `lan_station_list`, `ssid`, dan
`realtime_tx_rate`/`realtime_rx_rate` kembali KOSONG dari
panggilan status gabungan):

1. **Probe Field Kosong** — tombol baru di tab Diagnostik:
   meminta field-field kosong itu satu per satu / dalam grup
   kecil ala WebUI (7 panggilan GET proc_get berurutan) dan
   mencatat setiap respons mentahnya ke log, dibungkus penanda
   `=== PROBE FIELD KOSONG DIMULAI/SELESAI ===`.
2. **Kecepatan ↑/↓ dihitung aplikasi** — karena
   `realtime_tx_rate`/`rx_rate` kosong, AppState menyimpan
   sampel counter sebelumnya dan menghitung rate = selisih
   `realtime_tx_bytes`/`rx_bytes` ÷ selisih detik tiap
   refreshStatus. Sampel pertama / counter turun (reboot) →
   rate kosong ("—").
3. **Lingkaran data** — bila data bulanan terbaca: seperti
   sebelumnya ("Pemakaian Bulan Ini"). Bila kosong: lingkaran
   menampilkan total sesi (`realtime_tx_bytes` +
   `realtime_rx_bytes`) berlabel "Total Sesi Ini" dengan
   sublabel jujur "data bulanan belum terbaca dari perangkat".
4. **Kapasitas SMS persis** — terpakai = `sms_nv_rev_total` +
   `sms_nv_send_total` + `sms_nv_draftbox_total`, total =
   `sms_nv_total` (terkonfirmasi perangkat asli: 20). Heuristik
   lama dipertahankan sebagai fallback bila field itu absen.
5. **Baterai: `battery_pers` adalah LEVEL, bukan persen** —
   koreksi user dari uji v1.0: baterai fisik PENUH terbaca
   `battery_pers="3"` (tampilan lama keliru menulis "3%").
   Asumsi skala level **0–3** dari bukti itu: 3 = Penuh,
   2 = Tinggi, 1 = Rendah, 0 = Habis; nilai >3 ditampilkan
   "Level N" apa adanya. Persen asli hanya dari
   `battery_vol_percent`, dan hanya bila field itu terisi
   (di perangkat ini kosong). Tile Battery menampilkan teks
   level (+ "· Mengisi" bila `battery_charging`), dan baris
   detail menampilkan "Level 3 (Penuh)".

**Tema Advan** (ter-push di v1.2): tema aplikasi diganti dari
biru muda referensi ke branding Advan — primer pink magenta
**#EC008D** (dari logo resmi Advan), aksen terang #F95FB4, tinta
nyaris hitam hangat #16121A, latar #FBF8FA. Header dashboard
kini gradasi gelap #16121A → #2A1530 dengan teks putih;
lingkaran data ber-progress pink dengan track abu muda; ikon
tile berlatar pink muda #FCE4F1 dengan ikon pink gelap #C2187A;
tab aktif dan tombol utama mengikuti seed ColorScheme #EC008D.

**Logo final** (keputusan user 23 Nov 2026): huruf "i"
ditinggalkan — logo resmi = simbol WiFi varian B "gelap
premium": glyph WiFi gradasi pink #F95FB4 → #EC008D di atas
latar gelap #2A1530 → #16121A (master melengkung:
`../logo-final.png`). Untuk ikon aplikasi sudah dibuat varian
**kotak penuh 1024×1024** (tanpa sudut bulat, tanpa
transparansi): `assets/icon-1024.png`, plus salinan base64 satu
file teks `assets/icon-1024.b64.txt` — siap ditanam ke
AppIcon.appiconset oleh langkah workflow berikutnya (workflow
TIDAK diubah di v1.2; ikon di perangkat masih bawaan Flutter
sampai langkah itu dibuat).

**v1.2** (dari hasil Probe Field Kosong v1.1, perangkat asli
23 Nov 2026 — aturan emas: field array/objek RUSAK di panggilan
multi_data gabungan):

1. **Dashboard tuntas** — `station_list` & `lan_station_list`
   diambil dengan 2 GET terpisah TANPA multi_data mengikuti
   siklus refresh (model `ConnectedDevice`, parser toleran):
   tile Clients menampilkan total + rincian "WiFi N • kabel M",
   dan kartu "Perangkat Terhubung" merinci hostname, IP, MAC,
   tipe tiap klien. SSID asli dari grup datar
   `SSID1,HideSSID,AuthMode,MAX_Station_num` (multi_data OK —
   model `WifiSsidInfo`): baris SSID, mode keamanan, SSID
   disembunyikan, dan batas akses kini dari nilai perangkat
   yang sebenarnya (SSID1="iPocket", AuthMode="WPA2PSK",
   MAX_Station_num="32").
2. **Probe Data Bulanan** — tombol baru di Diagnostik:
   `GET cmd=data_counter` TANPA multi_data + `GET
   cmd=traffic_alert_info`, tercatat mentah. Dugaan kuat
   data_counter tetap kosong karena rencana Manajemen Data
   NONAKTIF di perangkat — lingkaran dashboard tetap fallback
   total sesi berlabel jujur; jangan dipaksa.
3. **Gelombang A — SMS penuh** (pola POST terkonfirmasi dari
   dump com.js): kirim `SEND_SMS` {Number, sms_time,
   MessageBody = hex UTF-16BE (`encodeSmsContent`, kebalikan
   decode yang sudah ada — `escapeMessage` WebUI tidak
   mengubah hex)}, simpan draf `SAVE_SMS` {SMSMessage,
   SMSNumber "nomor;", Index}, hapus per pesan `DELETE_SMS`
   {msg_id "id;"}, ketuk pesan belum dibaca → `SET_MSG_READ`
   {tag 0}, hapus semua `ALL_DELETE_SMS` {which_cgi},
   pengaturan `SET_MESSAGE_CENTER` {save_time, MessageCenter,
   status_save} (nomor pusat awal +62816124 dari katalog
   WebUI). Hapus memakai dialog konfirmasi; semua hasil POST
   tercatat di log Diagnostik; daftar SMS disegarkan setelah
   sukses. Tiga catatan asumsi yang ditandai juga di log:
   (a) format `sms_time` — definisi `getCurrentTimeString()`
   WebUI tidak ada di dump com.js (hanya call-site), dipakai
   format umum ZTE "yy;MM;dd;hh;mm;ss;+07"; (b) `which_cgi`
   hapus-semua = "inbox" (com.js mengambilnya dari location
   halaman WebUI); (c) pemetaan save_time validitas
   "0".."3" = 12 Jam/1 Hari/1 Minggu/Maksimum mengikuti urutan
   pilihan WebUI.
4. **Gelombang A — sambung/putus**: tombol di tab Status
   mengikuti `ppp_status` (Terhubung → "Putuskan" =
   DISCONNECT_NETWORK; sebaliknya CONNECT_NETWORK);
   result "success" = berhasil, lalu status disegarkan.
5. **Gelombang A — perangkat**: di tab Pengaturan, **Mulai
   Ulang Perangkat** (`REBOOT_DEVICE`, dialog konfirmasi
   tegas, hasil mentah dicatat ke log — goformId pola standar
   ZTE, verifikasinya adalah respons perangkat asli) dan
   **Ganti Kata Sandi Login** (`CHANGE_PASSWORD`, sandi lama &
   baru Base64 — terkonfirmasi com.js; form lama/baru/
   konfirmasi; sukses → sesi ditutup dan pengguna diarahkan
   ke layar login).

Asumsi tampilan lingkaran data: perangkat user TIDAK mengatur
batas data (Manajemen Data "Tidak diatur"), jadi ring digambar
proporsional terhadap **patokan tampilan 10 GB** — angka di tengah
lingkaran adalah total pemakaian bulan ini yang sebenarnya dari
`data_counter` (monthlySent + monthlyReceived) bila terbaca,
atau total sesi berjalan bila data bulanan kosong (lihat poin 3
di atas); patokan hanya mengatur seberapa penuh ring-nya.

## Struktur proyek

```
app/
├── pubspec.yaml            # package: ipocket; deps: flutter, http, crypto
├── analysis_options.yaml
├── IOS-NOTES.md            # potongan Info.plist wajib + bundle id
├── README-BUILD.md         # file ini
├── assets/
│   ├── icon-1024.png       # ikon aplikasi kotak penuh 1024×1024
│   │                       # (Logo B) — siap tanam ke AppIcon
│   └── icon-1024.b64.txt   # salinan base64 ikon (satu file teks)
└── lib/
    ├── main.dart           # MaterialApp "iPocket" → AppShell
    ├── app_state.dart      # state bersama (gateway, password, sesi) —
    │                       # hanya di memori, tidak disimpan permanen
    ├── reqproc_client.dart # klien reqproc (v1.0): Referer, cookie
    │                       # jar, login LOGIN sandi Base64 (hasil
    │                       # terstruktur), status gabungan, SMS +
    │                       # kapasitas, Tes Lengkap reqproc; juga
    │                       # rumah DiagEntry/DiagnosticsLog bersama;
    │                       # v1.2: station_list terpisah, grup
    │                       # SSID1, POST Gelombang A (SEND_SMS,
    │                       # SAVE_SMS, DELETE_SMS, SET_MSG_READ,
    │                       # ALL_DELETE_SMS, SET_MESSAGE_CENTER,
    │                       # CONNECT/DISCONNECT_NETWORK,
    │                       # REBOOT_DEVICE, CHANGE_PASSWORD),
    │                       # Probe Data Bulanan
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
    │                       # baterai persen/level, sinyal per jenis jaringan,
    │                       # data_counter Map/string, station_list
    │                       # List/string) + SmsCapacity + SmsMessage
    │                       # + decode/encode hex UTF-16BE;
    │                       # v1.2: ConnectedDevice + parseStationList
    │                       # + WifiSsidInfo (grup SSID1)
    └── screens/
        ├── app_shell.dart        # AppBar + navigasi bawah 4 tab
        ├── status_screen.dart    # dashboard: sambutan+login, header,
        │                       # tombol sambung/putus, lingkaran data
        │                       # bulanan/sesi, 4 tile, detail (SSID
        │                       # asli), daftar perangkat terhubung,
        │                       # auto-refresh 15 detik
        ├── sms_screen.dart       # SMS penuh: daftar + kapasitas,
        │                       # tulis/kirim, draf, hapus, tandai
        │                       # dibaca, hapus semua, pengaturan SMS
        ├── diagnostics_screen.dart # log request mentah + Tes Lengkap
        │                       # + Probe Field Kosong + Probe Data
        │                       # Bulanan
        └── settings_screen.dart  # gateway + mulai ulang perangkat
                                # + ganti kata sandi login
```

Tab Diagnostik adalah alat verifikasi lapangan: tombol **Jalankan
Tes Lengkap** sekarang menjalankan urutan reqproc (login → status
gabungan → daftar SMS → kapasitas SMS), dan semua request/respons
mentah tercatat untuk di-screenshot dan dicocokkan dengan perangkat
asli. Tombol **Probe Field Kosong** (v1.1) meminta field yang
kosong dari panggilan gabungan (`data_counter`, `station_list`,
`lan_station_list`, `ssid`, grup `SSID1,HideSSID,AuthMode,
MAX_Station_num`, dan kombinasi `data_counter` + counter sesi)
satu per satu dan mencatat respons mentahnya. Tombol **Probe
Data Bulanan** (v1.2) mencoba dua bentuk terakhir untuk
data bulanan: `data_counter` tanpa multi_data dan
`traffic_alert_info`. Tombol kedua,
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
