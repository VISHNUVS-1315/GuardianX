import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/firebase_runtime.dart';
import '../models/emergency_contact.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/realtime_sync_service.dart';
import '../services/sos_service.dart';
import '../widgets/sos_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _sync = RealtimeSyncService();
  Position? _position;
  List<EmergencyContact> _contacts = const [];
  bool _loadingLocation = false;
  String? _message;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _contacts = await LocalStore.loadContacts();
    if (mounted) setState(() {});
    await _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() {
      _loadingLocation = true;
      _message = null;
    });
    try {
      final position = await LocationService.current();
      if (mounted) setState(() => _position = position);
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<Position> _requirePosition() async {
    if (_position != null) return _position!;
    final current = await LocationService.current();
    if (mounted) setState(() => _position = current);
    return current;
  }

  Future<void> _showSosActions() async {
    _contacts = await LocalStore.loadContacts();
    final position = await _requirePosition();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101010),
      builder: (sheetContext) {
        final shareUrl = _sync.shareUrl;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Emergency actions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_contacts.length} trusted contact(s) configured',
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 18),
                _ActionButton(
                  icon: Icons.sms_outlined,
                  label: 'Send SOS by SMS',
                  onTap: () => _runAction(
                    sheetContext,
                    () => SosService.openSms(_contacts, position),
                  ),
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.chat_outlined,
                  label: 'Share SOS on WhatsApp',
                  onTap: () => _runAction(
                    sheetContext,
                    () => SosService.openWhatsApp(position),
                  ),
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.call,
                  label: 'Call emergency 112',
                  danger: true,
                  onTap: () => _runAction(
                    sheetContext,
                    SosService.callEmergency,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: _sync.active
                      ? Icons.location_disabled_outlined
                      : Icons.share_location_outlined,
                  label: _sync.active
                      ? 'Stop live safety session'
                      : 'Start live guardian tracking',
                  onTap: FirebaseRuntime.authReady
                      ? () => _toggleLiveSession(sheetContext)
                      : null,
                ),
                if (_sync.active && shareUrl != null) ...[
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.ios_share,
                    label: 'Share live tracking link',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showLiveShareSheet(shareUrl);
                    },
                  ),
                ],
                if (!FirebaseRuntime.authReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    FirebaseRuntime.error ??
                        'Firebase authentication is required for cloud live tracking.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleLiveSession(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    try {
      if (_sync.active) {
        await _sync.stop();
        _snack('Live safety session stopped.');
      } else {
        final shareUrl = await _sync.start(_contacts);
        _snack('Live guardian tracking started.');
        if (mounted && shareUrl.startsWith('http')) {
          await _showLiveShareSheet(shareUrl);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _showLiveShareSheet(String shareUrl) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101010),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Live tracking ready',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'This private link updates from your current safety session and expires automatically.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 14),
              SelectableText(
                shareUrl,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.sms_outlined,
                label: 'Send link by SMS',
                onTap: () => _runAction(
                  sheetContext,
                  () => SosService.openLiveShareSms(_contacts, shareUrl),
                ),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.chat_outlined,
                label: 'Share link on WhatsApp',
                onTap: () => _runAction(
                  sheetContext,
                  () => SosService.openLiveShareWhatsApp(shareUrl),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: shareUrl));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _snack('Live tracking link copied.');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext sheetContext,
    Future<void> Function() action,
  ) async {
    Navigator.of(sheetContext).pop();
    try {
      await action();
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _sync.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = _position;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          children: [
            const Row(
              children: [
                Icon(Icons.shield, size: 34),
                SizedBox(width: 10),
                Text(
                  'GuardianX',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Personal safety. Live, simple and ready.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      FirebaseRuntime.authReady
                          ? Icons.cloud_done_outlined
                          : Icons.phone_android,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        FirebaseRuntime.authReady
                            ? 'Firebase live sync connected'
                            : 'Local safety mode active',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FirebaseRuntime.authReady
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(child: SosButton(onActivated: _showSosActions)),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Hold to unlock emergency actions. Nothing is sent until you choose an action.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Current location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _loadingLocation ? null : _refreshLocation,
                          icon: _loadingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (p != null)
                      Text(
                        '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}\n'
                        'Accuracy ±${p.accuracy.toStringAsFixed(0)} m',
                        style: const TextStyle(color: Colors.white70),
                      )
                    else
                      Text(
                        _message ?? 'Waiting for GPS…',
                        style: const TextStyle(color: Colors.white60),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.people_outline,
                    value: '${_contacts.length}',
                    label: 'Guardians',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.location_searching,
                    value: _sync.active ? 'ON' : 'OFF',
                    label: 'Live session',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: danger ? const Color(0xFFD71920) : Colors.white,
        foregroundColor: danger ? Colors.white : Colors.black,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
