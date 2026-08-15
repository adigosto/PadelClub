import 'package:flutter/material.dart';

import 'package:padelclub_desktop/core/di/injection.dart';
import 'package:padelclub_desktop/main.dart' show PadelClubBootstrap;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sl.init();
  runApp(const PadelClubBootstrap());
}
