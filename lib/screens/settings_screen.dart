import 'package:flutter/material.dart';

import '../core/firebase_runtime.dart';
import '../models/emergency_contact.dart';
import '../services/local_store.dart';

class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  List<EmergencyContact> _contacts = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await LocalStore.loadContacts();
    if (mounted) setState(() => _contacts = contacts);
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();

    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add trusted contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone with country code',
                hintText: '+91xxxxxxxxxx',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final cleanName = name.text.trim();
              final cleanPhone = phone.text.replaceAll(RegExp(r'\s+'), '');
              if (cleanName.isEmpty || cleanPhone.length < 8) return;
              Navigator.pop(
                dialogContext,
                EmergencyContact(name: cleanName, phone: cleanPhone),
              );
            },
            child: Text('Add'),
          ),
        ],
      ),
    );

    name.dispose();
    phone.dispose();

    if (result == null) return;
    final next = [..._contacts, result];
    await LocalStore.saveContacts(next);
    setState(() => _contacts = next);
  }

  Future<void> _remove(int index) async {
    final next = [..._contacts]..removeAt(index);
    await LocalStore.saveContacts(next);
    setState(() => _contacts = next);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          Text(
            'Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Configure your trusted emergency network.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 20),
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    FirebaseRuntime.isReady
                        ? Icons.cloud_done
                        : Icons.cloud_off_outlined,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FirebaseRuntime.isReady
                              ? 'Firebase connected'
                              : 'Firebase not configured',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          FirebaseRuntime.isReady
                              ? 'Anonymous auth + Firestore live sync enabled.'
                              : 'Core SOS, GPS, nearby search and Medical ID '
                                  'still work locally.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trusted contacts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.filled(
                onPressed: _addContact,
                icon: Icon(Icons.add),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (_contacts.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No contacts yet. Add at least one trusted person so '
                  'GuardianX can prepare an SOS SMS with your live location.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          for (var i = 0; i < _contacts.length; i++) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Icon(Icons.person),
                ),
                title: Text(_contacts[i].name),
                subtitle: Text(_contacts[i].phone),
                trailing: IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _remove(i),
                  icon: Icon(Icons.delete_outline),
                ),
              ),
            ),
            SizedBox(height: 10),
          ],
          SizedBox(height: 24),
          Text(
            'Privacy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 10),
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Guardian contacts are stored locally. Medical ID uses '
                'encrypted device storage. Live location is written to '
                'Firestore only when you explicitly start a cloud safety '
                'session and Firebase is configured.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
