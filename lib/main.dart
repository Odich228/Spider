import 'dart:io';
import 'dart:convert';

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
  final support = await getApplicationSupportDirectory();
  var url = const String.fromEnvironment('SUPABASE_URL');
  var key = const String.fromEnvironment('SUPABASE_ANON_KEY');
  final configFile = File(p.join(support.path, 'cloud.json'));
  if (url.isEmpty && key.isEmpty && await configFile.exists()) {
    try {
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      url = config['url'] as String;
      key = config['key'] as String;
    } catch (_) {
      /* A damaged local configuration must not hide the library. */
    }
  }
  SupabaseClient? cloud;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      cloud = Supabase.instance.client;
    } catch (_) {
      // Keep the local library accessible if a cloud configuration is invalid.
    }
  }
  final directory = Directory(p.join(support.path, 'library'));
  await directory.create(recursive: true);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase.open(directory)),
        directoryProvider.overrideWithValue(directory),
        cloudProvider.overrideWithValue(cloud),
        cloudConnectionProvider.overrideWithValue((url: url, key: key)),
      ],
      child: const PautinaApp(),
    ),
  );
}

class PautinaApp extends ConsumerWidget {
  const PautinaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Паутина',
    debugShowCheckedModeBanner: false,
    theme: pautinaTheme(
      symbiote:
          ref.watch(libraryProvider).value?.settings['theme'] == 'symbiote',
    ),
    themeAnimationDuration:
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 350),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const LibraryScreen(),
  );
}
