import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'data/content_repository_remote.dart';
import 'data/local/local_content_cache.dart';
import 'data/remote/supabase_content_api.dart';
import 'providers/content_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/history_provider.dart';
import 'providers/language_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/reading_progress_provider.dart';
import 'providers/reading_text_scale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Supabase: URL + anon key se inyectan en compilación con --dart-define
  // (mismo patrón que EUROPEANA_API_KEY). La anon key es pública: solo da
  // acceso de lectura según el RLS configurado.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final supabaseReady = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  if (supabaseReady) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  final contentProvider = ContentProvider(
    RemoteContentRepository(
      // Sin variables → cliente null → el repo usa caché/seed locales.
      SupabaseContentApi(supabaseReady ? Supabase.instance.client : null),
      LocalContentCache(),
    ),
  );

  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  final premiumProvider = PremiumProvider();
  await premiumProvider.initialize();

  final favoritesProvider = FavoritesProvider();
  await favoritesProvider.initialize();

  final historyProvider = HistoryProvider();
  await historyProvider.initialize();

  final readingProgressProvider = ReadingProgressProvider();
  await readingProgressProvider.initialize();

  final readingTextScaleProvider = ReadingTextScaleProvider();
  await readingTextScaleProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: premiumProvider),
        ChangeNotifierProvider.value(value: favoritesProvider),
        ChangeNotifierProvider.value(value: historyProvider),
        ChangeNotifierProvider.value(value: readingProgressProvider),
        ChangeNotifierProvider.value(value: readingTextScaleProvider),
        ChangeNotifierProvider.value(value: contentProvider),
      ],
      child: const PeruEternoApp(),
    ),
  );
}
