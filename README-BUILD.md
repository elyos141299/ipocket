# iPocket — Struktur & Rencana Build

Aplikasi Flutter "iPocket": panel status untuk MiFi Advan iPocket MF01
(API reqproc perangkat) — pantau sinyal, baterai, perangkat terhubung,
dan SMS tanpa membuka browser. Spesifikasi API: `../API-CONTRACT.md`.

Versi: **v3.1.1** — patch ikut Run yang sama dengan v3.1 (dua keluhan user dari screenshot tab Tools v3.0 + micro-interaction):
- **Header bermerek**: judul app bar bukan lagi teks "iPocket" polos — marka `AppLogoMark` 28px + wordmark "iPocket" tebal (w800) di `app_shell.dart`, konsisten di semua tab.
- **Halaman "Gateway & Aplikasi"**: formulir gateway dicabut dari badan tab Tools (terlihat seperti tempelan) — grid Tools dapat tile baru **Gateway** (ikon router) yang membuka halaman khusus `lib/screens/settings/app_gateway_page.dart`. Isi sama persis (field alamat gateway, tombol Simpan Gateway — kini cyan tema, catatan) dengan perilaku simpan TIDAK berubah.
- **Semua field teks jadi panel statis**: `SettingsTextField` dirombak mengikuti pola `SettingsDropdown` v3.1 (label kecil tetap di dalam panel, tepi menyala cyan saat fokus, tanpa label melayang InputDecoration yang menimpa tepi field — cacat yang sama seperti dropdown di v3.0). Field mentah ber-label melayang ikut disamakan: sandi Wi-Fi (Wi-Fi Utama & Pengaturan Cepat), 3 field ganti kata sandi (Sistem), dan field dialog SMS (Nomor tujuan, Isi pesan, SMSC, Validitas pesan → `SettingsDropdown`). Satu-satunya TextField mentah tersisa = field sandi halaman masuk (desain khusus, dikecualikan). API `SettingsTextField` bertambah opsional `suffixIcon` & `hint`; perilaku semua field tidak berubah.
- **Micro-interaction (aplikasi tidak kaku)**: (1) tile Tools & baris hub menyusut tipis ke skala 0,97 saat ditekan (`PressScale` baru di `widgets.dart`, GestureDetector translucent + AnimatedScale 130 ms, ripple bawaan tetap jalan); (2) transisi antar-halaman fade + geser 4% konsisten untuk semua rute (`pageTransitionsTheme` + `_FadeSlideTransitionsBuilder` di `theme.dart`, 260 ms easeOutCubic); (3) busur gauge Beranda menyapu halus ke nilai baru tiap polling (`TweenAnimationBuilder` 650 ms di `_gaugeCard`); (4) perpindahan tab bawah fade + geser tipis 180 ms (Stack + Offstage + AnimatedOpacity/AnimatedSlide menggantikan IndexedStack, keadaan tab tetap tersimpan); (5) tombol Masuk gradasi di halaman login dibungkus `PressScale` (ripple InkWell-nya sudah ada). Semua animasi hanya opacity/transform → 60fps. Label versi di halaman masuk kini "v3.1.1".
Sebelumnya **v3.1** — poles dari uji lapangan v3.0 + pilihan user (Logo A & label baterai jujur):
- **Logo A RESMI** ("cincin gauge", gradasi cyan #00E5FF → biru #2979FF → ungu #B04DFF di atas navy): ikon aplikasi diganti (aset `assets/icon-1024.png` + `icon-1024.b64.txt` diregenerasi dari `../v31-assets/icon-A.png`; master project `../logo-final.png` ditimpa — pink varian B pensiun) dan logo di dalam aplikasi digambar ulang persis sebagai CustomPaint `AppLogoMark` (cincin ±270° + glyph WiFi sektor), dipakai besar di halaman masuk.
- **Halaman masuk profesional** (mockup `../v31-assets/login-mockup.png`): latar gradasi navy, logo A besar, "iPocket" + tagline, kartu form bertepi berisi label "KATA SANDI ADMIN" + field + tombol Masuk gradasi cyan→biru (Container gradasi + InkWell), error sebagai banner rapi DI ATAS kartu, petunjuk gateway di bawah kartu, label "v3.1" redup di bawah. Perilaku login tidak berubah.
- **Tombol tema diperbaiki**: `ColorScheme.fromSeed` mode gelap menurunkan primary jadi biru pucat (sebab tombol Simpan/Segarkan/Tulis SMS/Simpan Gateway tampil pucat bawaan Material di screenshot user) — kini primary/onPrimary (#00C2FF / #04121F) ditimpa eksplisit + `FilledButtonThemeData` dikunci di `lib/theme.dart`.
- **Gauge bulanan ASLI**: `getStatus` kini juga meminta `monthly_rx_bytes`, `monthly_tx_bytes`, `data_volume_limit_switch/size/unit` (grup status WebUI; terbukti terisi lewat Probe Persen Baterai v3.0: 1.067.155.788 / 158.831.344). Tengah gauge = "TOTAL BULAN INI" (rx+tx), sub-baris kecepatan live + "Sesi ini …". Fraksi busur: bila batas data aktif → total ÷ batas (rumus WebUI com.js: unit string "data", ukuran "<n>_<pengali>", byte = n × pengali × 1024 × 1024); selain itu total ÷ referensi lunak 10 GB (patokan tampilan, bukan batas perangkat).
- **Label baterai JUJUR** (pilihan user): level battery_pers 3/2/1/0 → "Tinggi" / "Sedang" / "Rendah" / "Sangat Rendah" — kata "Penuh" untuk level 3 HILANG dari seluruh aplikasi (level ≠ persen). Kartu Baterai Beranda: ikon baterai 3 segmen mengikuti level + ikon petir bila mengisi. Persen asli tetap tampil bila `battery_vol_percent` terisi.
- **Fix Hapus Semua SMS**: `ALL_DELETE_SMS` terbukti tidak menghapus apa pun (result "success" tapi pesan utuh) — diganti SATU `DELETE_SMS` massal berisi semua id yang tampil (format com.js: `ids.join(";") + ";"`), lalu daftar dimuat ulang; tombol nonaktif bila daftar kosong.
- **Halaman SMS profesional**: header kapasitas + tombol segarkan ikon, baris aksi bertema (Tulis SMS cyan, Pengaturan SMS outline navy, Hapus Semua outline merah lembut), pesan sebagai kartu berjarak, keadaan kosong terpusat berikon (widget `EmptyState` bersama).
- **Polling 2 detik + indikator LIVE** (permintaan user — teks "Diperbarui otomatis tiap 5 detik" dinilai tidak niat/tidak real-time): interval status 5 → **2 detik** (menggantikan pilihan 5 detik di v1.5), tombol "Segarkan" di Beranda DIHAPUS, diganti titik hijau berdenyut + teks "LIVE".
- **Fix label hantu Pengaturan Cepat**: `SettingsDropdown` bukan lagi `DropdownButtonFormField` (field itu saat fokus menggambar label berlekuk + salinan teks nilai menimpa tepi kartu di rekaman user) — kini panel statis (label tetap di dalam + `DropdownButton` polos). Audit `SectionLabel`: semua pemakaian selalu di atas kartu dengan jarak bersih.
Sebelumnya **v3.0** — ROMBAK TOTAL UI (permintaan user, mockup disetujui): struktur ala aplikasi **tpMiFi** (TP-Link) + palet **Speedtest by Ookla**. Fitur, perintah wire, logika, polling 5 detik, dan teks konfirmasi keamanan IDENTIK v2.0.2 — yang berubah hanya kulit & tata letak:
- **Palet baru** (token `lib/theme.dart`): latar navy #070B1F, header #0B1030, tab bar #0A0F28, kartu #121A3D bertepi #1E2A55, panel #16224A, aksen cyan #00C2FF, gradasi gauge #00E5FF → #2979FF → #B04DFF, teks #EAF2FF / #8FB8E8 / #5F7DB3. Pink Advan & palet v1.4–v2.0 ditinggalkan total di UI; ikon aplikasi di home screen TIDAK berubah. Logo login digambar ulang gradasi cyan → ungu di atas navy.
- **Tab bawah baru**: Beranda, Tools, SMS, Diagnostik (Status → Beranda, Pengaturan → Tools).
- **Beranda**: header operator/jaringan; **gauge setengah lingkaran** ala Ookla (tengah: TOTAL SESI INI + kecepatan live ↓/↑; fraksi busur = total sesi terhadap skala lunak 1 GB, cap 100%); 3 kartu statistik yang bisa diketuk — BATERAI (→ Hemat Daya), SINYAL (→ Sistem & Perangkat), PERANGKAT (→ Perangkat Terhubung); tombol Sambung/Putus gaya pil outline cyan (label & perilaku sama); kartu Perangkat Terhubung + detail SSID seperti sebelumnya.
- **Tools**: grid ikon 4 kolom ala tpMiFi — Wi-Fi (hub: Pengaturan Cepat, Wi-Fi Utama, Wi-Fi Lanjutan, WPS, Filter MAC), Jaringan (hub: Mode Koneksi, Pilih Jaringan, APN, Manajemen Data, Router & DHCP), Perangkat (Perangkat Terhubung), Baterai (Hemat Daya), Firewall (halaman firewall v2.0), Sistem (hub: Sistem & Perangkat [info/mulai ulang/matikan/reset/sandi], SNTP, PIN SIM, Pembaruan Firmware), SMS & Diagnostik (lompat tab). Pengaturan gateway aplikasi tetap di bawah grid.
- **Probe Persen Baterai (BARU)** — tombol baru di tab Diagnostik: satu GET proc_get dengan cmd = SELURUH daftar field grup status WebUI persis com.js utuh (array dasar 12 field + array status 40 field + 3 field SMS, digabung satu `cmd` dengan `multi_data=1` — persis cara WebUI memintanya), lalu mencatat nilai mentah `battery_vol_percent` & `battery_pers` ke log. Latar: WebUI menampilkan persen dari field itu (jatuh ke 100 bila kosong — fallback itu TIDAK ditiru); di semua tes, `getStatus` aplikasi selalu menerima `""` — dugaan firmware hanya mengisinya bila diminta dalam grup persis WebUI. `getStatus` utama tidak diubah; kartu baterai Beranda tetap menampilkan persen bila `batteryPercent` terisi, selain itu label level seperti sekarang.
Sebelumnya **v2.0.2** — `CardTheme` dikembalikan ke `CardThemeData` di `lib/theme.dart` (parameter `cardTheme` ThemeData di Flutter 3.32 memang bertipe `CardThemeData?`; Run CI #13 gagal di situ. `AppBarTheme` tetap tanpa akhiran Data — sudah terbukti benar di 3.32).
Sebelumnya **v2.0** — Gelombang B+C+D LENGKAP dalam satu build +
poles tampilan profesional (lihat bagian **v2.0** di bawah).
Sebelumnya **v1.5** — perbaikan format `sms_time` kirim SMS
sesuai definisi `getCurrentTimeString()` lib.js (zona polos
tanpa zero-pad: WIB `"+7"`, bukan `"+07"` — penyebab pasti
SEND_SMS `result "failure"`), dan auto-refresh status
dipercepat 15 → **5 detik** (keputusan user).
Sebelumnya **v1.4** — tema GELAP + PUTIH di seluruh aplikasi
(permintaan user: tema terang kurang disukai), wire SMS
ditambah `notCallback:"true"` persis bentuk WebUI, dan
Penemuan Terarah JS diperluas ke `js/lib.js` (konteks ±2000)
memburu definisi fungsi pembentuk wire SMS.
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
auto-refresh 5 detik selama tab tampil & sudah login. Tab SMS
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
**Tema terang ini DIBATALKAN di v1.4** — user kurang suka
tampilan terang; lihat bagian **v1.4** (tema gelap + putih).

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

**v1.3** (dari verifikasi perangkat asli v1.2, 23 Nov 2026 —
ikon Logo B tampil di home screen, tema Advan, Clients/
Perangkat Terhubung/SSID persis WebUI; lihat addendum
API-CONTRACT 14:20. Catatan: langkah workflow penanam ikon
dibuat setelah push v1.2 dan ikon terverifikasi tampil —
paragraf logo di atas adalah catatan saat v1.2 ditulis):

1. **Logo login = glyph WiFi** — layar masuk tidak lagi
   memakai lingkaran huruf "i": widget `WifiLogoMark`
   menggambar glyph WiFi (tiga busur + titik, gradasi pink
   #F95FB4 → #EC008D) di atas kotak gelap membulat
   #2A1530 → #16121A dengan **CustomPaint**, meniru Logo B.
   Tanpa aset biner baru (push-files menolak biner; ikon PNG
   tetap hanya untuk AppIcon lewat workflow).
2. **Baris "Batas akses maksimum" dihapus** dari detail tab
   Status: nilainya `MAX_Station_num` = kapabilitas
   perangkat (32), menyesatkan — setting WebUI sebenarnya 3
   dan field sumbernya belum ketemu (nanti dari hasil
   Penemuan Terarah JS).
3. **Pengaturan SMS: default laporan pengiriman OFF** —
   inspeksi live membuktikan keadaan perangkat sebenarnya
   "Nonaktif"; v1.2 keliru default ON. SMSC (+62816124) &
   validitas (Maksimum) tetap.
4. **Penemuan Terarah JS** — tombol baru di Diagnostik
   (`ApiDiscoveryTargeted` di `discovery.dart`): unduh PENUH
   `js/wifi.js`, `js/net.js`, `js/sim_device.js`, lalu untuk
   kata kunci spesifik per file catat konteks **±1200
   karakter di sekitar SETIAP kemunculan** ke log, dipecah
   entri ≤3500 karakter TANPA membuang isi (jendela tumpang
   tindih digabung; penanda file + kata kunci + nomor
   segmen/potongan; case-insensitive). Kata kunci wifi.js:
   goformId, setWifiBasic, getWifiBasic, MAX_Access, mac,
   MacFilter, block, SET_WIFI, channel, Country. net.js:
   DHCP_SETTING, lanDhcp, FILTER, DMZ, REBOOT, restart,
   TURN_OFF, FOTA, SNTP, traffic. sim_device.js: sms,
   SmsSetting, save_time, MessageCenter, status_save.
   Tujuannya: memastikan nama field wire gelombang
   pengaturan (simpan WiFi, filter MAC, DHCP, DMZ, reboot,
   SNTP, pengaturan SMS) yang di dump v0.4 hanya terpotong.
5. **Probe Baterai & Bulanan** — tombol "Probe Data Bulanan"
   ganti nama & diperluas: tiga panggilan baterai TANPA
   multi_data (`battery_vol_percent` sendiri, `battery_vol`
   sendiri, grup `battery_pers,battery_vol_percent,
   battery_charging,battery_vol`) memburu persen baterai
   asli seperti WebUI (73% saat inspeksi live — dari
   panggilan gabungan field-nya selalu ""). Dua panggilan
   bulanan v1.2 (data_counter tanpa multi_data +
   traffic_alert_info) DIPERTAHANKAN sebagai pembukti ulang
   bila rencana data diaktifkan user.

**v1.4** (permintaan user 23 Nov 2026 ±14:39 + hasil tes
kirim SMS v1.3; lihat addendum API-CONTRACT 14:37):

1. **Tema GELAP + PUTIH di seluruh aplikasi** — user kurang
   suka tema terang v1.2/v1.3. Latar scaffold sangat gelap
   **#121016**, kartu/panel **#1E1A24–#262030**, teks utama
   **putih**, teks sekunder putih 60–70%, garis tepi & track
   ring putih ±10%. Pink Advan #EC008D/#F95FB4 HANYA aksen
   kecil: tombol utama (seed ColorScheme gelap), indikator
   tab aktif, toggle ON, ring progres, ikon aksen, fokus
   field. Berlaku konsisten di semua permukaan: `main.dart`
   memakai ColorScheme gelap dari seed yang sama +
   scaffoldBackgroundColor/cardColor/divider/snackbar gelap;
   layar login, dashboard (header tetap gradasi gelap
   #16121A → #2A1530; tile kini wadah ikon #262030 berikon
   #F95FB4; teks redup diganti putih 38–70%), dialog
   (Pengaturan SMS, konfirmasi hapus, tulis SMS — mengikuti
   tema gelap Material), field teks (isi gelap, teks putih,
   fokus pink), dan tab bar (latar #1E1A24, indikator pink,
   ikon/label putih). Logo login `WifiLogoMark`
   dipertahankan apa adanya (sudah gelap premium).
2. **Wire SMS + `notCallback:"true"`** — kelima POST SMS
   (`SEND_SMS`, `SAVE_SMS`, `DELETE_SMS`, `SET_MSG_READ`,
   `ALL_DELETE_SMS`) kini menyertakan field `notCallback`
   bernilai string `"true"`, persis bentuk objek di kode
   asli hasil Penemuan Terarah. Asumsi lain TIDAK diubah
   dan tetap dicatat di log: format `sms_time` (umum ZTE),
   `which_cgi`="inbox", pemetaan `save_time` validitas.
3. **Penemuan Terarah JS + `js/lib.js`** — target keempat:
   kata kunci `getCurrentTimeString`, `encodeMessage`,
   `escapeMessage` dengan konteks LEBIH LEBAR **±2000
   karakter** per kemunculan (file lain tetap ±1200).
   Definisi tiga fungsi ini tidak ada di wifi/net/
   sim_device.js — hampir pasti di lib.js — dan merupakan
   buruan terakhir untuk perbaikan kirim SMS yang pasti
   (tes v1.3: SEND_SMS → result "failure").

**v1.5** (hasil Penemuan Terarah lib.js di v1.4 + keputusan
user 23 Nov 2026 ±14:48; lihat addendum API-CONTRACT ±15:00):

1. **Perbaikan `sms_time` — penyebab SMS ketemu & DITUTUP** —
   definisi lib.js ketemu: `escapeMessage` ternyata fungsi
   identitas dan `encodeMessage` persis implementasi aplikasi
   (hex UTF-16BE) — keduanya BENAR sejak awal. Yang salah
   hanya zona waktu di `smsTimeString`: aplikasi mengirim
   `"+07"` (zero-pad), sedangkan `getCurrentTimeString()`
   WebUI menghasilkan bilangan polos dari
   `0 - getTimezoneOffset()/60` → Jakarta **`"+7"`**.
   `smsTimeString` kini meniru JS persis dari
   `DateTime.timeZoneOffset` (jam = menit/60; bulat →
   `"+<jam>"`/`"<jam>"` polos; bersisa menit → desimal tanpa
   padding, mis. `"+5.5"`). Catatan log SEND_SMS diperbarui:
   sms_time kini PASTI, bukan asumsi. Asumsi tersisa hanya
   `which_cgi` ALL_DELETE_SMS dan pemetaan `save_time`
   SET_MESSAGE_CENTER. Catatan tes: kirim SMS user ditujukan
   ke nomor perdana di dalam MiFi itu sendiri — tes ulang
   v1.5 membuktikan apakah self-send diterima; bila masih
   failure, uji ke nomor lain sebelum menyimpulkan.
2. **Polling status 5 detik** — keputusan user ("Percepat
   jadi 5 detik"). Timer auto-refresh tab Status 15 → 5
   detik; label UI "Diperbarui otomatis tiap 5 detik." dan
   komentar terkait diselaraskan. Timeout HTTP Penemuan JS
   (15 detik di `discovery.dart`) BUKAN polling — tidak
   diubah.

**v2.0** (Gelombang B+C+D sekaligus dari `../FULL-SPEC-BCD.md`
— spek wire digali dari file JS WebUI UTUH yang diberikan user,
bukan lagi sampel terpotong; semua goformId/field/enum di bawah
mengikuti spek itu persis):

1. **Pengaturan menjadi HUB gaya Settings iPhone** — tab
   Pengaturan kini daftar grup (ikon dalam kotak aksen + judul +
   chevron): Wi-Fi, Jaringan, Perangkat, Lanjutan, Sistem, plus
   kartu Aplikasi (gateway, dipertahankan). Tiap grup membuka
   sub-halaman sendiri di `lib/screens/settings/`.
2. **Wi-Fi (B)** — Pengaturan Cepat (`QUICK_SETUP_EX` + prefill
   utuh); Wi-Fi Utama (`SET_WIFI_SSID1_SETTINGS` dengan aturan
   kondisional AuthMode persis spek: WPA → shared_mode=cipher +
   passphrase Base64, SHARED/WEP → kunci WEP + satu WEPxSelect;
   saklar Wi-Fi `SET_WIFI_INFO`; batas akses = `MAX_Access_num`
   — konflik "32 vs 3" TUTUP: 32 = `MAX_Station_num` kapabilitas,
   tidak pernah dikirim); Wi-Fi Lanjutan (`SET_WIFI_INFO`
   advance: negara/kanal/batas akses; mode/band/rate diteruskan
   apa adanya, `wifi_band`/`wifi_11n_cap` tidak dikirim karena
   flag support mati di unit ini); WPS (`WIFI_WPS_SET`, `wps_pin`
   hanya mode PIN, pemisah PIN dibuang); Filter MAC
   (`WIFI_MAC_FILTER`, hanya daftar sesuai mode yang dikirim;
   mode Putih memakai KONFIRMASI KERAS yang menampilkan daftar
   final + MAC perangkat user sendiri); Hemat Daya (cakupan
   `SET_WIFI_COVERAGE`; waktu tidur BACA-SAJA — enum nilainya
   di set.js yang tidak tersedia).
3. **Jaringan (C)** — Mode Koneksi (`SET_CONNECTION_MODE`);
   Pilih Jaringan (`SCAN_NETWORK` + polling
   `m_netselect_status`/`m_netselect_result` tiap 1000 ms,
   `SET_NETWORK {NetworkNumber, Rat 0/2/7, nSubrat}`;
   `net_select` ditampilkan baca-saja — enum
   `SET_BEARER_PREFERENCE` GELAP, tidak dibuat pemilih); APN
   (`APN_PROC_EX` save/set_default/delete, profil diurai dari
   pemisah "($)"); Manajemen Data (`DATA_LIMIT_SETTING`,
   pengali format `<n>_<pengali>` dipertahankan; tanggal reset
   memang tidak ada di wire).
4. **Perangkat Terhubung (B6)** — daftar station/lan + nama
   dari `cmd=hostNameList`; Blokir/Lepas blokir pola persis
   `{ACL_mode:"2", macFilteringMode:"2", wifi_hostname_black_list,
   wifi_mac_black_list}`; Ganti nama `EDIT_HOSTNAME {mac,
   hostname}` + validasi karakter WebUI.
5. **Lanjutan (D)** — Router & DHCP (`DHCP_SETTING` utuh +
   `dhcp_reboot_flag:1`, peringatan ganti IP); Firewall: FW_SYS
   (manajemen jarak jauh + ping WAN), Filter Port
   (`BASIC_SETTING`, `ADD/DEL_IP_PORT_FILETER_V4V6` — hapus
   hanya v4, format delete_id v6 tidak pasti), Port Forwarding
   (`VIRTUAL_SERVER`, `FW_FORWARD_ADD/DEL`), Port Mapping
   (`ADD/DEL_PORT_MAP`), DMZ (`DMZ_SETTING`, IP hanya bila
   aktif), Filter URL (`websURLFilters`, `URL_FILTER_ADD/
   DELETE`), UPnP (`UPNP_SETTING`); SNTP (POST `SNTP` persis
   spek: timezone dibelah "_", tanpa detik; `SNTP_Getdatastatic`
   saat buka & setelah simpan); PIN SIM BACA-SAJA
   (pinnumber/pin_status/puknumber — halaman PIN nonaktif total
   di perangkat); FOTA (`IF_UPGRADE {select_op:"check",
   ota_manual_check_roam_state:1}` + status + `SetUpgAutoSetting`;
   select_op lanjutan tidak ditawarkan, SEBAGIAN).
6. **Sistem (D18)** — Info Perangkat (model, SW/HW dicoba dari
   cmd versi umum, IP/MAC/operator), Mulai Ulang
   (`REBOOT_DEVICE {}` — kini PASTI dari spek, catatan "belum
   terbukti" di klien dihapus), Matikan (`TURN_OFF_DEVICE {}`),
   Setel Ulang Pabrik (`RESTORE_FACTORY_SETTINGS {}`, konfirmasi
   ganda), Ganti Kata Sandi (dipindah ke sini dari hub lama).
7. **DILEWATI total** (support mati di set.js unit ini):
   Multi SSID/Guest (`HAS_MULTI_SSID:false`), DDNS
   (`DDNS_SUPPORT:false`), HTTP Share/Kartu SD
   (`SD_CARD_SUPPORT:false` — status SD tetap ditampilkan
   dashboard seperti sebelumnya).
8. **Keamanan UX** — konfirmasi untuk: Matikan, Reset Pabrik
   (ganda), Filter MAC mode Putih (keras), DMZ, blokir
   perangkat, pindah jaringan, DHCP (reboot + peringatan IP),
   dan simpan Wi-Fi Utama/Lanjutan/Pengaturan Cepat (peringatan
   putus & sambung ulang manual bila SSID/sandi berubah).
   Setelah perintah reboot/matikan/reset, UI menjelaskan
   aplikasi akan kehilangan koneksi sesaat.
9. **Poles profesional** — token desain terpusat
   `lib/theme.dart` (`AppColors`/`AppSpace`/`AppRadius`/
   `AppText` + `buildAppTheme()` dengan tema komponen seragam:
   kartu radius 16, field terisi panel tanpa garis, tombol &
   saklar pink) dan widget bersama `lib/widgets.dart`
   (`SectionLabel` uppercase redup, `HubRow`/`HubGroup`,
   `InfoRow`/`InfoCard`, `FormCard`, keadaan
   `LoadingState`/`EmptyState`/`ErrorState` yang rapi,
   `SaveButton`, `confirmAction`, `SettingsPageShell`).
   Dashboard Status, SMS, dan Diagnostik diselaraskan ke token
   yang sama (nilai warna identik dengan v1.4 — perilaku
   terbukti TIDAK berubah: polling 5 detik, login, SMS,
   sambung/putus utuh).
10. **Kode baru**: `lib/settings_api.dart` (lapisan API B/C/D
    di atas `ReqprocClient.procGet/procPost`) dan
    `lib/settings_models.dart` (parser toleran semua data
    pengaturan). `AppState` menambah getter `api` +
    `turnOffDevice()`/`restoreFactory()`.

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
    │                       # Probe Data Bulanan; v1.3: probe
    │                       # diperluas baterai tanpa multi_data
    │                       # (Probe Baterai & Bulanan); v1.4:
    │                       # notCallback:"true" di semua POST SMS
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
    │                       # v1.3: penemuan terarah — unduh PENUH
    │                       # wifi/net/sim_device.js, konteks
    │                       # ±1200 karakter per kemunculan kata
    │                       # kunci spesifik per file, tanpa potong
    │                       # v1.4: + js/lib.js konteks ±2000 —
    │                       # buruan getCurrentTimeString/
    │                       # encodeMessage/escapeMessage
    ├── theme.dart          # v2.0: token desain terpusat
    │                       # (AppColors/AppSpace/AppRadius/AppText)
    │                       # + buildAppTheme() — dipakai SEMUA tab
    ├── widgets.dart        # v2.0: widget bersama (SectionLabel,
    │                       # HubRow/HubGroup, InfoRow/InfoCard,
    │                       # FormCard, Loading/Empty/ErrorState,
    │                       # SaveButton, confirmAction,
    │                       # SettingsPageShell, field form standar)
    ├── settings_models.dart # v2.0: parser toleran data pengaturan
    │                       # B/C/D (WifiBasic, WifiAdvance, WpsInfo,
    │                       # MacFilterInfo, hostNameList, APN "($)",
    │                       # NetSelectEntry, DataLimitInfo, DhcpInfo,
    │                       # rule firewall, SntpInfo, FotaInfo, PinInfo)
    ├── settings_api.dart   # v2.0: lapisan API Gelombang B/C/D di
    │                       # atas ReqprocClient (semua goformId &
    │                       # field persis FULL-SPEC-BCD.md)
    ├── models.dart         # DeviceStatus reqproc (parse toleran:
    │                       # baterai persen/level, sinyal per jenis jaringan,
    │                       # data_counter Map/string, station_list
    │                       # List/string) + SmsCapacity + SmsMessage
    │                       # + decode/encode hex UTF-16BE;
    │                       # v1.2: ConnectedDevice + parseStationList
    │                       # + WifiSsidInfo (grup SSID1)
    └── screens/
        ├── app_shell.dart        # AppBar + navigasi bawah 4 tab
        ├── status_screen.dart    # dashboard: sambutan+login (logo
        │                       # WiFi CustomPaint sejak v1.3; tema
        │                       # gelap + putih sejak v1.4), header,
        │                       # tombol sambung/putus, lingkaran data
        │                       # bulanan/sesi, 4 tile, detail (SSID
        │                       # asli), daftar perangkat terhubung,
        │                       # auto-refresh 5 detik
        ├── sms_screen.dart       # SMS penuh: daftar + kapasitas,
        │                       # tulis/kirim, draf, hapus, tandai
        │                       # dibaca, hapus semua, pengaturan SMS
        ├── diagnostics_screen.dart # log request mentah + Tes Lengkap
        │                       # + Probe Field Kosong + Probe Baterai
        │                       # & Bulanan + Penemuan Terarah JS
        ├── settings_screen.dart  # v2.0: HUB Pengaturan gaya
        │                       # Settings iPhone (grup Wi-Fi,
        │                       # Jaringan, Perangkat, Lanjutan,
        │                       # Sistem) + kartu gateway aplikasi
        └── settings/           # v2.0: sub-halaman pengaturan
            ├── wifi_quick_page.dart    # Pengaturan Cepat (QUICK_SETUP_EX)
            ├── wifi_main_page.dart     # Wi-Fi Utama + saklar Wi-Fi
            ├── wifi_advanced_page.dart # Wi-Fi Lanjutan
            ├── wifi_wps_page.dart      # WPS (PIN/PBC)
            ├── wifi_mac_page.dart      # Filter MAC (konfirmasi keras Putih)
            ├── wifi_power_page.dart    # Hemat Daya (cakupan + tidur baca-saja)
            ├── devices_page.dart       # Perangkat Terhubung (blokir/rename)
            ├── net_mode_page.dart      # Mode Koneksi
            ├── net_select_page.dart    # Pilih Jaringan (scan + polling)
            ├── net_apn_page.dart       # APN (daftar + form profil)
            ├── net_data_page.dart      # Manajemen Data
            ├── adv_router_page.dart    # Router & DHCP
            ├── adv_firewall_page.dart  # hub Firewall + FW_SYS + UPnP
            ├── fw_filter_page.dart     # Filter Port (+ form tambah)
            ├── fw_forward_page.dart    # Port Forwarding
            ├── fw_portmap_page.dart    # Port Mapping
            ├── fw_dmz_page.dart        # DMZ
            ├── fw_url_page.dart        # Filter URL
            ├── adv_sntp_page.dart      # Waktu (SNTP)
            ├── adv_pin_page.dart       # PIN SIM (baca-saja)
            ├── adv_fota_page.dart      # Pembaruan Firmware (FOTA)
            └── system_page.dart        # Info, daya (reboot/matikan/
                                    # reset pabrik), ganti kata sandi
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
Baterai & Bulanan** (v1.2 sebagai "Probe Data Bulanan",
diperluas v1.3) mencoba `battery_vol_percent`, `battery_vol`,
dan grup baterai — semua tanpa multi_data — untuk memburu
persen baterai asli, plus dua bentuk terakhir untuk data
bulanan: `data_counter` tanpa multi_data dan
`traffic_alert_info`. Tombol **Penemuan Terarah JS** (v1.3,
diperluas v1.4) mengunduh penuh `js/wifi.js`, `js/net.js`,
`js/sim_device.js`, `js/lib.js` dan mencatat konteks ±1200
karakter di sekitar setiap kemunculan kata kunci spesifik
per file (nama field wire gelombang pengaturan) tanpa
memotong isi konteks; khusus lib.js konteksnya ±2000
karakter, memburu definisi `getCurrentTimeString`,
`encodeMessage`, dan `escapeMessage`. Tombol kedua,
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
