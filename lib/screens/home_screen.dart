import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/firebase_runtime.dart';
import '../core/theme.dart';
import '../models/emergency_contact.dart';
import '../services/crash_detection_service.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/realtime_sync_service.dart';
import '../services/sos_service.dart';
import '../widgets/sos_button.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _sync = RealtimeSyncService();
  final _crashDetector = CrashDetectionService();

  Position? _position;
  List<EmergencyContact> _contacts = const [];
  bool _loadingLocation = false;
  bool _crashDetectionEnabled = false;
  bool _handlingCrash = false;
  String? _message;
  String? _crashStatus;
  CrashSignal? _lastCrashSignal;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _contacts = await LocalStore.loadContacts();
    final crashEnabled = await LocalStore.loadCrashDetectionEnabled();

    if (CrashDetectionService.isSupportedPlatform && crashEnabled) {
      try {
        await _crashDetector.start(_handlePotentialCrash);
        _crashDetectionEnabled = true;
        _crashStatus = 'Monitoring device motion for possible crash events.';
      } catch (e) {
        _crashDetectionEnabled = false;
        _crashStatus = 'Crash detection could not start: $e';
      }
    } else {
      _crashDetectionEnabled = false;
    }

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

  Future<void> _toggleCrashDetection(bool enabled) async {
    if (!CrashDetectionService.isSupportedPlatform) {
      _snack('Real crash monitoring is available on Android and iOS devices.');
      return;
    }

    try {
      if (enabled) {
        await _crashDetector.start(_handlePotentialCrash);
        await LocalStore.saveCrashDetectionEnabled(true);
        if (mounted) {
          setState(() {
            _crashDetectionEnabled = true;
            _crashStatus =
                'Monitoring device motion for possible crash events.';
          });
        }
        _snack('Crash detection armed.');
      } else {
        await _crashDetector.stop();
        await LocalStore.saveCrashDetectionEnabled(false);
        if (mounted) {
          setState(() {
            _crashDetectionEnabled = false;
            _crashStatus = 'Crash detection is off.';
          });
        }
        _snack('Crash detection turned off.');
      }
    } catch (e) {
      await LocalStore.saveCrashDetectionEnabled(false);
      if (mounted) {
        setState(() {
          _crashDetectionEnabled = false;
          _crashStatus = 'Crash detection could not start: $e';
        });
      }
      _snack(e.toString());
    }
  }

  Future<void> _runCrashDemo() async {
    await _handlePotentialCrash(
      CrashSignal(
        detectedAt: DateTime.now(),
        accelerationMagnitude: 36,
        rotationMagnitude: 4.2,
      ),
    );
  }

  Future<void> _handlePotentialCrash(CrashSignal signal) async {
    if (_handlingCrash || !mounted) return;

    _handlingCrash = true;
    _lastCrashSignal = signal;
    setState(() {
      _crashStatus =
          'Strong impact detected. Waiting for safety confirmation.';
    });

    try {
      final dismissedAsSafe = await _showCrashCountdown(signal);
      if (dismissedAsSafe) {
        if (mounted) {
          setState(() {
            _crashStatus = 'Impact alert cancelled — user confirmed safe.';
          });
        }
        _snack('Crash alert cancelled.');
        return;
      }

      await _activateCrashAlert();
    } finally {
      _handlingCrash = false;
      if (mounted) setState(() {});
    }
  }

  Future<bool> _showCrashCountdown(CrashSignal signal) async {
    if (!mounted) return true;

    var secondsLeft = 15;
    Timer? timer;

    final dismissedAsSafe = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            timer ??= Timer.periodic(Duration(seconds: 1), (timer) {
              if (!dialogContext.mounted) {
                timer.cancel();
                return;
              }

              if (secondsLeft <= 1) {
                timer.cancel();
                Navigator.of(dialogContext).pop(false);
                return;
              }

              setDialogState(() => secondsLeft--);
            });

            return AlertDialog(
              icon: Icon(
                Icons.car_crash_outlined,
                size: 42,
                color: GuardianXTheme.danger,
              ),
              title: Text('Possible crash detected'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GuardianX detected a strong motion event '
                    '(${signal.accelerationG.toStringAsFixed(1)} g equivalent sensor reading).',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Confirm you are safe within $secondsLeft seconds. '
                    'Otherwise GuardianX will start the help flow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Crash detection is a safety aid and can produce false alerts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: Icon(Icons.check_circle_outline),
                  label: Text("I'm safe"),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: GuardianXTheme.danger,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.sos),
                  label: Text('Send help now'),
                ),
              ],
            );
          },
        );
      },
    );

    timer?.cancel();
    return dismissedAsSafe == true;
  }

  Future<void> _activateCrashAlert() async {
    _contacts = await LocalStore.loadContacts();
    String? shareUrl = _sync.shareUrl;
    String? cloudError;

    if (_sync.active || FirebaseRuntime.authReady) {
      try {
        if (!_sync.active) {
          shareUrl = await _sync.start(_contacts);
        }
        await _sync.updateStatus('help');
      } catch (e) {
        cloudError = e.toString();
      }
    }

    Position? alertPosition;
    try {
      alertPosition = await _requirePosition();
    } catch (_) {
      alertPosition = null;
    }

    if (mounted) {
      setState(() {
        _crashStatus = cloudError == null
            ? 'Possible crash help flow active.'
            : 'Possible crash detected. Cloud tracking unavailable; local alert flow active.';
      });
    }

    if (_contacts.isEmpty) {
      _snack(
        'Possible crash alert active, but no trusted guardian is configured. Add a guardian in Settings.',
      );
      return;
    }

    try {
      await SosService.openCrashAlertSms(
        _contacts,
        alertPosition,
        liveShareUrl: shareUrl,
      );
      _snack(
        'Guardian crash alert prepared. Review and send the SMS from your phone.',
      );
    } catch (e) {
      _snack('Crash alert activated, but the SMS app could not open: $e');
    }
  }

  Future<void> _showSosActions() async {
    _contacts = await LocalStore.loadContacts();
    final position = await _requirePosition();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        final shareUrl = _sync.shareUrl;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Emergency actions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  '${_contacts.length} trusted contact(s) configured',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: 18),
                _ActionButton(
                  icon: Icons.sms_outlined,
                  label: 'Send SOS by SMS',
                  onTap: () => _runAction(
                    sheetContext,
                    () => SosService.openSms(_contacts, position),
                  ),
                ),
                SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.chat_outlined,
                  label: 'Share SOS on WhatsApp',
                  onTap: () => _runAction(
                    sheetContext,
                    () => SosService.openWhatsApp(position),
                  ),
                ),
                SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.call,
                  label: 'Call emergency 112',
                  danger: true,
                  onTap: () => _runAction(
                    sheetContext,
                    SosService.callEmergency,
                  ),
                ),
                SizedBox(height: 10),
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
                if (_sync.active) ...[
                  SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'Mark live status: NEED HELP',
                    danger: true,
                    onTap: () => _runAction(
                      sheetContext,
                      () => _setSafetyStatus('help'),
                    ),
                  ),
                ],
                if (_sync.active && shareUrl != null) ...[
                  SizedBox(height: 10),
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
                  SizedBox(height: 8),
                  Text(
                    FirebaseRuntime.error ??
                        'Firebase authentication is required for cloud live tracking.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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

  Future<void> _setSafetyStatus(String status) async {
    await _sync.updateStatus(status);
    if (mounted) setState(() {});
    final label = switch (status) {
      'safe' => 'I am safe',
      'moving' => 'On the move',
      'help' => 'Need help',
      _ => 'Live tracking',
    };
    _snack('Live status updated: $label.');
  }

  String get _statusLabel => switch (_sync.status) {
    'safe' => 'I am safe',
    'moving' => 'On the move',
    'help' => 'NEED HELP',
    'tracking' => 'Tracking',
    _ => 'Ended',
  };

  IconData get _statusIcon => switch (_sync.status) {
    'safe' => Icons.verified_user_outlined,
    'moving' => Icons.directions_walk,
    'help' => Icons.warning_amber_rounded,
    _ => Icons.location_searching,
  };

  Future<void> _showLiveShareSheet(String shareUrl) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Live tracking ready',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'This private link updates from your current safety session and expires automatically.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 14),
              SelectableText(
                shareUrl,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 16),
              _ActionButton(
                icon: Icons.sms_outlined,
                label: 'Send link by SMS',
                onTap: () => _runAction(
                  sheetContext,
                  () => SosService.openLiveShareSms(_contacts, shareUrl),
                ),
              ),
              SizedBox(height: 10),
              _ActionButton(
                icon: Icons.chat_outlined,
                label: 'Share link on WhatsApp',
                onTap: () => _runAction(
                  sheetContext,
                  () => SosService.openLiveShareWhatsApp(shareUrl),
                ),
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: shareUrl));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _snack('Live tracking link copied.');
                },
                icon: Icon(Icons.copy),
                label: Text('Copy link'),
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
    unawaited(_crashDetector.stop());
    unawaited(_sync.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = _position;
    final crashSupported = CrashDetectionService.isSupportedPlatform;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 110),
          children: [
            Row(
              children: [
                Icon(Icons.shield, size: 34),
                SizedBox(width: 10),
                Text(
                  'GuardianX',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Personal safety. Live, simple and ready.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 22),
            Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      FirebaseRuntime.authReady
                          ? Icons.cloud_done_outlined
                          : Icons.phone_android,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        FirebaseRuntime.authReady
                            ? 'Firebase live sync connected'
                            : 'Local safety mode active',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FirebaseRuntime.authReady
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            Center(child: SosButton(onActivated: _showSosActions)),
            SizedBox(height: 14),
            Center(
              child: Text(
                'Hold to unlock emergency actions. Nothing is sent until you choose an action.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: crashSupported && _crashDetectionEnabled,
                    onChanged: crashSupported && !_handlingCrash
                        ? _toggleCrashDetection
                        : null,
                    secondary: Icon(
                      _crashDetectionEnabled
                          ? Icons.car_crash
                          : Icons.car_crash_outlined,
                    ),
                    title: Text(
                      'Crash detection (Beta)',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      crashSupported
                          ? 'Uses motion sensors to detect a strong impact plus sudden rotation. A 15-second safety check runs before the help flow.'
                          : 'Real sensor monitoring is available on Android/iOS. Chrome can still test the alert workflow below.',
                    ),
                  ),
                  if (_crashStatus != null) ...[
                    Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _crashStatus!,
                          style: TextStyle(
                            color: _handlingCrash
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_lastCrashSignal != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(18, 4, 18, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Last impact reading: ${_lastCrashSignal!.accelerationG.toStringAsFixed(1)} g · '
                          'rotation ${_lastCrashSignal!.rotationMagnitude.toStringAsFixed(1)} rad/s',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(18, 8, 18, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handlingCrash ? null : _runCrashDemo,
                        icon: Icon(Icons.science_outlined),
                        label: Text('Test crash alert countdown'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location),
                        SizedBox(width: 10),
                        Expanded(
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
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (p != null)
                      Text(
                        '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}\n'
                        'Accuracy ±${p.accuracy.toStringAsFixed(0)} m',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      )
                    else
                      Text(
                        _message ?? 'Waiting for GPS…',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.people_outline,
                    value: '${_contacts.length}',
                    label: 'Guardians',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.location_searching,
                    value: _sync.active ? 'ON' : 'OFF',
                    label: 'Live session',
                  ),
                ),
              ],
            ),
            if (_sync.active) ...[
              SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_statusIcon),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Live safety status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _sync.status == 'help'
                                  ? Colors.white
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Update this so anyone with your private tracking link can understand your current situation.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35),
                      ),
                      SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _setSafetyStatus('safe'),
                            icon: Icon(Icons.check_circle_outline),
                            label: Text("I'm safe"),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _setSafetyStatus('moving'),
                            icon: Icon(Icons.directions_walk),
                            label: Text('Moving'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _setSafetyStatus('help'),
                            style: FilledButton.styleFrom(
                              backgroundColor: GuardianXTheme.danger,
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(Icons.warning_amber_rounded),
                            label: Text('Need help'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
        minimumSize: Size.fromHeight(54),
        backgroundColor: danger
            ? GuardianXTheme.danger
            : Theme.of(context).colorScheme.primary,
        foregroundColor: danger
            ? Colors.white
            : Theme.of(context).colorScheme.onPrimary,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
