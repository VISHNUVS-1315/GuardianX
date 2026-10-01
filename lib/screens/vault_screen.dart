// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

import '../core/firebase_runtime.dart';
import '../services/vault_service.dart';

class VaultScreen extends StatefulWidget {
  VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      await VaultService.pickAndUpload();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(VaultItem item) async {
    try {
      await VaultService.open(item);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _delete(VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete document?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VaultService.delete(item);
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Secure Vault')),
      floatingActionButton: FirebaseRuntime.authReady
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.upload_file),
              label: Text(_uploading ? 'Uploading…' : 'Add document'),
            )
          : null,
      body: !FirebaseRuntime.authReady
          ? const _VaultSetupState()
          : StreamBuilder<List<VaultItem>>(
              stream: VaultService.watch(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Vault unavailable: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No documents yet. Add IDs, insurance documents or other safety files you want available from your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _open(item),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          child: Icon(Icons.description_outlined),
                        ),
                        title: Text(item.name),
                        subtitle: Text(_formatBytes(item.size)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'open') _open(item);
                            if (value == 'delete') _delete(item);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'open', child: Text('Open')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _VaultSetupState extends StatelessWidget {
  const _VaultSetupState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56),
            SizedBox(height: 16),
            Text(
              'Connect Firebase to use the vault',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'The vault requires Firebase Authentication, Firestore and Storage. No secret keys are stored in the repository.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
