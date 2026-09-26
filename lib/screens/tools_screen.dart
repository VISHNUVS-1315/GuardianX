import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) throw Exception('Unable to open portal.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          const Text(
            'Safety tools',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Direct access to useful official services.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _ToolCard(
            icon: Icons.report_outlined,
            title: 'Public grievance portal',
            subtitle: 'Open the Government of India grievance portal.',
            onTap: () => _open('https://pgportal.gov.in/'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.receipt_long_outlined,
            title: 'E-Challan checker',
            subtitle: 'Open the official Parivahan e-Challan portal.',
            onTap: () => _open(
              'https://echallan.parivahan.gov.in/index/accused-challan',
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.call_outlined,
            title: 'Emergency 112',
            subtitle: 'Open India’s emergency number in the dialer.',
            onTap: () => _open('tel:112'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.health_and_safety_outlined,
            title: 'National Health Portal',
            subtitle: 'Open verified public health information.',
            onTap: () => _open('https://www.nhp.gov.in/'),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          try {
            await onTap();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
