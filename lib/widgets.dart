import 'package:flutter/material.dart';

import 'theme.dart';

/// Judul seksi kecil uppercase redup (gaya Settings iPhone),
/// lengkap dengan jarak standar di atas & bawahnya.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.top = AppSpace.xl});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: AppSpace.sm),
      child: Text(text.toUpperCase(), style: AppText.sectionLabel),
    );
  }
}

/// Kotak ikon aksen: panel gelap membulat + ikon pink terang —
/// dipakai baris hub dan tile di seluruh aplikasi.
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
        color: AppColors.panel,
        borderRadius: AppRadius.tileBorder,
      ),
      child: Icon(icon, color: color, size: 21),
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
    return ListTile(
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

/// Keadaan memuat standar: indikator pink di tengah + label.
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
            Icon(icon, size: 44, color: AppColors.textFaint),
            const SizedBox(height: AppSpace.md),
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

/// Tombol simpan utama yang seragam (pink, lebar penuh, ikon centang).
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
        minimumSize: const Size.fromHeight(48),
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
        message: 'Masuk dulu di tab Status untuk membuka pengaturan ini.',
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
class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperStyle: AppText.hint,
      ),
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
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label, helperText: helper),
      items: items,
      onChanged: onChanged,
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
