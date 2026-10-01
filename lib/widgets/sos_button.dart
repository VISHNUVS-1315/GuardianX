// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.onActivated});

  final Future<void> Function() onActivated;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  Timer? _timer;
  bool _holding = false;
  bool _busy = false;

  void _start() {
    if (_busy) return;
    setState(() => _holding = true);
    _timer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || !_holding) return;
      setState(() {
        _busy = true;
        _holding = false;
      });
      try {
        await widget.onActivated();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (mounted) setState(() => _holding = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _cancel(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GuardianXTheme.danger,
          border: Border.all(
            color: GuardianXTheme.danger,
            width: 5,
          ),
          boxShadow: [
            BoxShadow(
              color: GuardianXTheme.danger.withValues(alpha: 0.28),
              blurRadius: _holding ? 48 : 28,
              spreadRadius: _holding ? 12 : 5,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _busy
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sos_rounded,
                    size: 62,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _holding ? 'KEEP HOLDING' : 'HOLD 3 SEC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
