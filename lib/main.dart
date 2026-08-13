import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/library_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LibraryStore();
  await store.load();
  runApp(F95FeedApp(store: store));
}
