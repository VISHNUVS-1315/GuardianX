import 'dart:io';

void main() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stderr.writeln('AndroidManifest.xml not found. Run flutter create first.');
    exitCode = 1;
    return;
  }

  var content = file.readAsStringSync();
  const marker = '<application';
  const permissions = <String>[
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
  ];

  for (final permission in permissions) {
    if (!content.contains(permission)) {
      content = content.replaceFirst(marker, '    $permission\n    $marker');
    }
  }

  file.writeAsStringSync(content);
  stdout.writeln('GuardianX Android permissions configured.');
}
