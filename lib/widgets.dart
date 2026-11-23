import 'package:flutter/material.dart';

import 'theme.dart';

/// Judul seksi kecil uppercase redup (gaya Settings iPhone),
/// lengkap dengan jarak standar di atas & bawahnya.
///
/// Audit v3.1 (temuan rekaman user di Pengaturan Cepat): label
/// ini selalu dipakai sebagai anak ListView TEPAT DI ATAS kartu
/// (FormCard/InfoCard/HubGroup) dengan jarak atas AppSpace.xl —
/// tidak pernah di dalam kartu, jadi tidak bisa menimpa tepi
/// kartu. Teks yang terlihat menimpa di rekaman ternyata berasal
/// dari dropdown form-field lama; lihat catatan di
/// SettingsDropdown.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.top = AppSpace.xl});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: AppSpace.sm),
      // v4.0: tanda aksen gradasi kecil di kiri label — detail
      // identitas yang konsisten di semua seksi.
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 12,
            decoration: const BoxDecoration(
              gradient: AppGradients.accentLine,
              borderRadius: AppRadius.pillBorder,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(text.toUpperCase(), style: AppText.sectionLabel),
        ],
      ),
    );
  }
}

/// Kotak ikon aksen: panel navy membulat bertepi + ikon cyan —
/// dipakai baris hub dan tile di seluruh aplikasi.
/// v4.0: permukaan gradasi glassy (panel → cardHi) agar tidak
/// datar.
class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, this.color = AppColors.accent});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.cardHi, AppColors.panel],
        ),
        borderRadius: AppRadius.tileBorder,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.border),
        ),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

/// Pembungkus micro-interaction v3.1.1: saat ditekan, anak
/// menyusut tipis ke skala 0,97 lalu kembali — umpan balik
/// sentuh yang halus tanpa mengganggu gestur anak (detektor
/// translucent, ketukan tetap diteruskan ke InkWell/ListTile
/// di dalamnya, ripple bawaan tetap jalan). Animasi hanya
/// transform → aman 60fps.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Satu baris hub pengaturan: ikon dalam kotak aksen + judul +
/// subjudul opsional + chevron kanan. Seluruh baris bisa diketuk.
class HubRow extends StatelessWidget {
  const HubRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    // v3.1.1: baris hub ikut menyusut tipis saat ditekan
    // (PressScale) di atas ripple ListTile bawaannya.
    return PressScale(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xs,
        ),
        leading: IconBox(icon, color: iconColor),
        title: Text(title, style: AppText.rowTitle),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: AppText.rowSubtitle),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textFaint,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Kartu berisi sekumpulan baris hub (grup pengaturan). Baris
/// dipisah garis tipis agar tampil seperti daftar Settings iOS.
class HubGroup extends StatelessWidget {
  const HubGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 70));
      }
      rows.add(children[i]);
    }
    return Card(child: Column(children: rows));
  }
}

/// Kartu form standar: latar kartu + padding seragam.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpace.cardInner,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Baris label–nilai untuk halaman info/baca-saja.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.rowValue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu berisi baris-baris [InfoRow] dengan pemisah tipis.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.rows});

  final List<InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const Divider(height: 1, indent: 16));
      children.add(rows[i]);
    }
    return Card(child: Column(children: children));
  }
}

/// Keadaan memuat standar: indikator cyan di tengah + label.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Memuat dari perangkat…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSpace.lg),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Keadaan kosong standar: ikon redup + pesan.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // v4.0: ikon di dalam lingkaran glassy, bukan
            // ikon polos melayang.
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: AppGradients.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 38, color: AppColors.textFaint),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keadaan gagal memuat: pesan + tombol coba lagi.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off,
              size: 44,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpace.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tombol simpan utama yang seragam (cyan, lebar penuh, ikon centang).
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.onPressed,
    this.label = 'Simpan',
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}

/// Dialog konfirmasi standar. [danger] mewarnai tombol aksi merah.
/// Mengembalikan true bila user menekan tombol aksi.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Snackbar hasil aksi yang seragam.
void showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Kerangka halaman pengaturan: menangani keadaan belum login,
/// memuat, dan gagal secara seragam, lalu menampilkan [body]
/// sebagai ListView ber-padding standar.
class SettingsPageShell extends StatelessWidget {
  const SettingsPageShell({
    super.key,
    required this.loading,
    required this.error,
    required this.loggedIn,
    required this.onRetry,
    required this.children,
  });

  final bool loading;
  final String? error;
  final bool loggedIn;
  final VoidCallback onRetry;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!loggedIn) {
      return const EmptyState(
        icon: Icons.lock_outline,
        message: 'Masuk dulu di tab Beranda untuk membuka pengaturan ini.',
      );
    }
    if (loading) return const LoadingState();
    if (error != null) {
      return ErrorState(message: error!, onRetry: onRetry);
    }
    return ListView(padding: AppSpace.page, children: children);
  }
}

/// Field teks standar untuk form pengaturan.
///
/// v3.1.1: panel statis seperti SettingsDropdown v3.1 — label
/// kecil TETAP di dalam panel di atas isian, TANPA label
/// melayang InputDecoration. Label melayang lama menimpa tepi
/// atas field (terlihat jelas di formulir gateway tab Tools
/// pada screenshot user) dan terasa seperti tempelan. API
/// (controller/label/helper/keyboardType/obscure/maxLines)
/// tidak berubah; tambahan opsional: [suffixIcon] (mis. tombol
/// mata sandi) dan [hint]. Tepi panel menyala cyan saat fokus.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final Widget? suffixIcon;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: AppRadius.tileBorder,
            border: Border.all(
              color: _focused ? AppColors.primary : AppColors.border,
              width: _focused ? 1.3 : 1.0,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      keyboardType: widget.keyboardType,
                      obscureText: widget.obscure,
                      maxLines: widget.maxLines,
                      style: AppText.rowTitle,
                      decoration: InputDecoration.collapsed(
                        hintText: widget.hint,
                        hintStyle: const TextStyle(
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                  ),
                  if (widget.suffixIcon != null) widget.suffixIcon!,
                ],
              ),
            ],
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(widget.helper!, style: AppText.hint),
          ),
      ],
    );
  }
}

/// Dropdown standar untuk form pengaturan.
class SettingsDropdown<T> extends StatelessWidget {
  const SettingsDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    // v3.1: BUKAN DropdownButtonFormField lagi. Di rekaman layar
    // user (Pengaturan Cepat v3.0), field form-field itu saat
    // fokus menggambar label melayang berlekuk (notch) DAN salinan
    // teks nilai "WPA2-PSK" muncul menimpa tepi kartu di atasnya.
    // Implementasi ini panel statis: wadah panel + label kecil
    // tetap di dalam + DropdownButton polos tanpa InputDecorator
    // — tidak ada label melayang, tidak ada teks hantu. API &
    // perilaku (value/items/onChanged) tidak berubah.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: AppRadius.tileBorder,
            // v4.0: tepi token border — selaras panel
            // SettingsTextField (sebelumnya tanpa tepi).
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.panel,
                borderRadius: AppRadius.tileBorder,
                iconEnabledColor: AppColors.textSecondary,
                style: AppText.rowTitle,
              ),
            ],
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(helper!, style: AppText.hint),
          ),
      ],
    );
  }
}

/// Baris saklar standar untuk form pengaturan.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppText.rowTitle),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: AppText.rowSubtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
