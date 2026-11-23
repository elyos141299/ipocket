import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

String _or(String? v) => (v == null || v.isEmpty) ? '—' : v;

String _fmtRate(int? v) {
  if (v == null) return '—';
  if (v < 1024) return '$v B/s';
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB/s';
  return '${(v / (1024 * 1024)).toStringAsFixed(2)} MB/s';
}

String _fmtBytes(int? v) {
  if (v == null) return '—';
  if (v < 1024) return '$v B';
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
  if (v < 1024 * 1024 * 1024) {
    return '${(v / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _fmtUptime(int? seconds) {
  if (seconds == null) return '—';
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h jam $m menit';
  if (m > 0) return '$m menit $s detik';
  return '$s detik';
}

/// Layar awal: panel koneksi (password admin) + status perangkat.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final TextEditingController _pwController;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _pwController =
        TextEditingController(text: AppState.instance.adminPassword);
  }

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final status = state.status;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _connectPanel(context, state),
            const SizedBox(height: 16),
            if (state.lastError != null) ...<Widget>[
              Text(
                state.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (status == null)
              const Text(
                'Belum ada data status. Tekan "Masuk & Muat Status" untuk mulai.',
              )
            else
              ..._statusTiles(context, status),
          ],
        );
      },
    );
  }

  Widget _connectPanel(BuildContext context, AppState state) {
    final gen = state.loginGeneration;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Gateway: ${state.gateway}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwController,
              obscureText: !_showPassword,
              onChanged: (v) => state.adminPassword = v,
              decoration: InputDecoration(
                labelText: 'Password admin MiFi',
                helperText: 'Hanya disimpan selama aplikasi berjalan.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: state.busy ? null : () => state.connect(),
                  icon: const Icon(Icons.login),
                  label: const Text('Masuk & Muat Status'),
                ),
                const SizedBox(width: 8),
                if (gen != null)
                  OutlinedButton.icon(
                    onPressed:
                        state.busy ? null : () => state.refreshStatus(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Muat Ulang'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.busy) const LinearProgressIndicator(),
            Text(
              gen == null
                  ? 'Status: belum terhubung'
                  : 'Status: terhubung (login Gen $gen)',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusTiles(BuildContext context, DeviceStatus s) {
    return <Widget>[
      Card(
        child: Column(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.cell_tower),
              title: Text(_or(s.networkProvider)),
              subtitle: Text('Operator • ${_or(s.networkType)}'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(_or(s.connectionLabel)),
              subtitle: const Text('Status koneksi'),
            ),
          ],
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              _signalBars(s.signalBars),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      s.signalDbm == null ? '—' : '${s.signalDbm} dBm',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Kekuatan sinyal'
                      '${s.signalDbmSource == null ? '' : ' (${s.signalDbmSource})'}'
                      ' • Bar: ${s.signalBars?.toString() ?? '—'}/5',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.battery_full),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _or(s.batteryValue),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    s.batteryCharging == null
                        ? 'Baterai'
                        : (s.batteryCharging!
                            ? 'Baterai • mengisi daya'
                            : 'Baterai'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Card(
        child: Column(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.speed),
              title: Text(
                'Unduh ${_fmtRate(s.rxRate)} • Unggah ${_fmtRate(s.txRate)}',
              ),
              subtitle: Text(
                'Total unduh ${_fmtBytes(s.rxBytes)} • '
                'Total unggah ${_fmtBytes(s.txBytes)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: Text(_fmtUptime(s.uptimeSeconds)),
              subtitle: const Text('Lama koneksi berjalan (uptime)'),
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: Text(s.stationCount?.toString() ?? '—'),
              subtitle: Text(
                'Perangkat terhubung'
                '${s.maxAccessNum == null ? '' : ' (maks ${s.maxAccessNum})'}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: Text(_or(s.smsUnread)),
              subtitle: const Text('SMS belum terbaca'),
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: Text(_or(s.ssid)),
              subtitle: Text('SSID • IP LAN ${_or(s.lanIp)}'),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _signalBars(int? bars) {
    final b = bars ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(5, (i) {
        final active = i < b;
        return Container(
          width: 6,
          height: 6.0 + i * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? Colors.teal : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
