import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/firebase_runtime.dart';

class VaultItem {
  const VaultItem({
    required this.id,
    required this.name,
    required this.storagePath,
    required this.size,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String storagePath;
  final int size;
  final DateTime? createdAt;
}

class VaultService {
  VaultService._();

  static User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (!FirebaseRuntime.authReady || user == null) {
      throw Exception('Firebase authentication is required for the vault.');
    }
    return user;
  }

  static CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vault');
  }

  static Stream<List<VaultItem>> watch() {
    final uid = _user.uid;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['createdAt'];
        return VaultItem(
          id: doc.id,
          name: data['name']?.toString() ?? 'Document',
          storagePath: data['storagePath']?.toString() ?? '',
          size: (data['size'] as num?)?.toInt() ?? 0,
          createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
        );
      }).toList(growable: false);
    });
  }

  static Future<void> pickAndUpload() async {
    final user = _user;
    final file = await FilePicker.pickFile();
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('Vault files are limited to 10 MB each.');
    }

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath =
        'users/${user.uid}/vault/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(file.name)),
    );

    await _collection(user.uid).add({
      'name': file.name,
      'size': bytes.length,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> open(VaultItem item) async {
    final user = _user;
    if (user.uid.isEmpty) throw Exception('Authentication is unavailable.');
    if (item.storagePath.isEmpty) throw Exception('Missing storage path.');
    final url = await FirebaseStorage.instance.ref(item.storagePath).getDownloadURL();
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) throw Exception('Unable to open this document.');
  }

  static Future<void> delete(VaultItem item) async {
    final user = _user;
    if (item.storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(item.storagePath).delete();
      } catch (_) {
        // Continue so stale metadata can still be removed.
      }
    }
    await _collection(user.uid).doc(item.id).delete();
  }

  static String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
