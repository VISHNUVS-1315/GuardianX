import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseRuntime.initialize();
  runApp(const GuardianXApp());
}
