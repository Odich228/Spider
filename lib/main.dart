import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/providers.dart';
import 'app/theme.dart';
import 'core/database/app_database.dart';
import 'features/library/presentation/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseClient? cloud;
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: key);
    cloud = Supabase.instance.client;
  }
  final support = await getApplicationSupportDirectory();
  final directory = Directory(p.join(support.path, 'library'));
  await directory.create(recursive: true);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase.open(directory)),
        directoryProvider.overrideWithValue(directory),
        cloudProvider.overrideWithValue(cloud),
      ],
      child: const PautinaApp(),
    ),
  );
}

class PautinaApp extends StatelessWidget {
  const PautinaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Паутина',
    debugShowCheckedModeBanner: false,
    theme: pautinaTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const LibraryScreen(),
  );
}
