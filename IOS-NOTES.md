# Catatan iOS — iPocket

Bundle id (netral): `id.oroboo.ipocket`

File ini BUKAN proyek iOS utuh — hanya potongan konfigurasi wajib yang
harus ada di `ios/Runner/Info.plist` hasil `flutter create`, karena
aplikasi ini berbicara HTTP polos ke perangkat di jaringan lokal
(MiFi iPocket, gateway default 192.168.0.1).

## Potongan Info.plist yang wajib ditambahkan

Tambahkan dua entri berikut ke dalam `<dict>` utama `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Aplikasi perlu mengakses jaringan lokal untuk membaca status MiFi iPocket di rumahmu.</string>
<key>NSAppTransportSecurity</key>
<dict>
	<key>NSAllowsLocalNetworking</key>
	<true/>
</dict>
```

## Kenapa keduanya wajib

- **NSLocalNetworkUsageDescription** — sejak iOS 14, akses ke jaringan
  lokal memicu dialog izin. Tanpa teks ini, iOS menolak akses secara
  diam-diam dan semua request ke MiFi gagal. Teks di atas tampil ke
  pengguna saat dialog izin pertama kali muncul.
- **NSAppTransportSecurity > NSAllowsLocalNetworking = true** —
  pengecualian ATS khusus jaringan lokal. API goform MiFi hanya HTTP
  polos (tidak ada HTTPS di perangkat), dan pengecualian ini mengizinkan
  HTTP hanya untuk alamat lokal — bukan untuk internet umum.

## Catatan tambahan

- Aplikasi hanya menghubungi gateway MiFi di LAN (default
  `192.168.0.1`, bisa diganti di tab Pengaturan). Tidak ada server
  eksternal yang dihubungi.
- iPhone harus terhubung ke WiFi iPocket (atau jaringan yang sama
  dengan MiFi) agar gateway bisa dijangkau.
- Untuk sideload (AltStore/SideStore, provisioning gratis), bundle id
  `id.oroboo.ipocket` dipakai apa adanya; tanda tangan diurus alat
  sideload, bukan oleh proyek ini.
