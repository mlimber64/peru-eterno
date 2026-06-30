import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
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
      ],
      child: const PeruEternoApp(),
    ),
  );
}
