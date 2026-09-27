import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('firebase.json');
  final Map<String, dynamic> config = file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};

  config['auth'] = <String, dynamic>{
    'providers': <String, dynamic>{'anonymous': true},
  };

  final firestore = Map<String, dynamic>.from(
    (config['firestore'] as Map?) ?? const <String, dynamic>{},
  );
  firestore['rules'] = 'firebase.rules';
  config['firestore'] = firestore;

  final storage = Map<String, dynamic>.from(
    (config['storage'] as Map?) ?? const <String, dynamic>{},
  );
  storage['rules'] = 'storage.rules';
  config['storage'] = storage;

  final hosting = Map<String, dynamic>.from(
    (config['hosting'] as Map?) ?? const <String, dynamic>{},
  );
  hosting['public'] = 'build/web';
  hosting['ignore'] = <String>[
    'firebase.json',
    '**/.*',
    '**/node_modules/**',
  ];
  hosting['rewrites'] = <Map<String, String>>[
    <String, String>{'source': '**', 'destination': '/index.html'},
  ];
  config['hosting'] = hosting;

  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(config)}\n');
  stdout.writeln('GuardianX firebase.json configured.');
}
