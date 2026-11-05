import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/library_store.dart';
import 'src/manager_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LibraryStore();
  await store.load();
  await manager.load();
  runApp(F95FeedApp(store: store));
}
