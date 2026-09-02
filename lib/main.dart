import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/app_info.dart';
import 'core/navigation/app_navigation.dart';
import 'data/content_repository_remote.dart';
import 'data/local/local_content_cache.dart';
import 'data/remote/supabase_content_api.dart';
import 'providers/audio_player_provider.dart';
import 'providers/collectibles_provider.dart';
import 'providers/content_provider.dart';
import 'providers/daily_story_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/history_provider.dart';
import 'providers/interactive_story_provider.dart';
import 'providers/language_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/reading_progress_provider.dart';
import 'providers/reading_text_scale_provider.dart';
import 'services/account_data_service.dart';
import 'services/entitlement_service.dart';
import 'services/analytics_service.dart';
import 'services/error_reporter_service.dart';
import 'services/home_widget_service.dart';
import 'services/review_prompt_service.dart';
import 'services/streak_notification_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/user_progress_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lato y Playfair Display se sirven desde assets/google_fonts/ (bundleadas
  // en el binario), no por red: evita depender de internet en el primer
  // arranque y una llamada a Google en cada instalación nueva. Ver
  // assets/google_fonts/README.md para cómo regenerar el set de pesos.
  GoogleFonts.config.allowRuntimeFetching = false;

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

  // Auth anónima: da un user_id estable para sincronizar progreso (racha,
  // quiz, coleccionables, finales) con Supabase. Se lanza sin `await` a
  // propósito — es una llamada de red y el arranque de la app no debe
  // esperarla; hasta que resuelva, `supabaseAuthService.userId.value` es
  // null y todo sigue funcionando 100% local, igual que si Supabase no
  // estuviera configurado.
  final supabaseAuthService = SupabaseAuthService(
    supabaseReady ? Supabase.instance.client : null,
  );
  unawaited(supabaseAuthService.initialize());

  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  // Captura de errores de Dart. Se instala lo antes posible —justo después de
  // tener idioma y sesión— porque un fallo de arranque es exactamente el que
  // más interesa ver. Los crashes nativos y ANRs no pasan por aquí: esos los
  // reporta Play Console (Android Vitals) sin necesidad de SDK.
  ErrorReporterService.supabase(
    client: supabaseReady ? Supabase.instance.client : null,
    auth: supabaseAuthService,
    localeProvider: () => languageProvider.currentLanguage,
  ).install();

  // Acceso premium verificado en servidor. Como el resto de piezas de
  // Supabase, es opcional: sin configurar, sin sesión o sin la migración
  // aplicada, PremiumProvider se comporta como siempre (estado local).
  final entitlementService = EntitlementService(
    client: supabaseReady ? Supabase.instance.client : null,
    auth: supabaseAuthService,
  );

  final premiumProvider = PremiumProvider(entitlements: entitlementService);

  // Analítica propia (misma decisión que el crash reporting: en el Supabase
  // del proyecto, sin SDK de terceros, para no contradecir la política de
  // privacidad ni añadir un procesador que declarar). Se construye aquí, tras
  // `premiumProvider`, porque marca cada evento con si el usuario paga o no:
  // sin ese dato no se puede separar "no le interesa" de "no puede".
  final analytics = AnalyticsService.supabase(
    client: supabaseReady ? Supabase.instance.client : null,
    auth: supabaseAuthService,
    sessionId: AnalyticsService.newSessionId(),
    localeProvider: () => languageProvider.currentLanguage,
    premiumProvider: () => premiumProvider.isPremium,
  );
  analytics.installLifecycleFlush();
  analytics.log(AnalyticsService.appOpen);
  // Solo el estado persistido (disco local) bloquea el arranque. La conexión
  // con Google Play / App Store va sin `await`, igual que la auth anónima de
  // Supabase: es canal nativo + red, y esperarla aquí dejaba la app en negro
  // hasta que la tienda respondiera (o para siempre, en un dispositivo sin
  // Play Services). Cuando resuelve, notifica y la UI se actualiza sola.
  await premiumProvider.initialize();
  unawaited(premiumProvider.connectStore());

  // El acceso vigente se consulta al servidor en segundo plano, y otra vez
  // cada vez que cambia la sesión: al vincular la cuenta a un correo o al
  // entrar en otro dispositivo, el premium y la prueba ya usada viajan con
  // ella.
  unawaited(premiumProvider.syncEntitlement());
  supabaseAuthService.userId.addListener(
    () => unawaited(premiumProvider.syncEntitlement()),
  );

  final favoritesProvider = FavoritesProvider();
  await favoritesProvider.initialize();

  final historyProvider = HistoryProvider();
  await historyProvider.initialize();

  final readingProgressProvider = ReadingProgressProvider();
  await readingProgressProvider.initialize();

  final readingTextScaleProvider = ReadingTextScaleProvider();
  await readingTextScaleProvider.initialize();

  final dailyStoryProvider = DailyStoryProvider();
  await dailyStoryProvider.initialize(
    premiumProvider.isPremium,
    languageProvider.currentLanguage,
  );

  // Recordatorio diario de racha. Se reprograma al arrancar y cada vez que
  // cambia el estado de la historia del día: en cuanto el usuario lee, el
  // aviso de esta noche se cancela — recordarle algo que ya hizo es la forma
  // más rápida de que desactive las notificaciones.
  // Valoración en la tienda: el servicio decide cuándo pedirla (a partir
  // del tercer momento bueno, una vez por versión). Las pantallas solo
  // le avisan de que ha pasado algo bueno.
  final reviewPrompts = ReviewPromptService(appVersion: AppInfo.version);

  final streakNotifications = StreakNotificationService();

  Future<void> refreshStreakReminder() async {
    final streak = dailyStoryProvider.currentStreak;
    await streakNotifications.refresh(
      alreadyReadToday: dailyStoryProvider.isCompletedToday,
      title: languageProvider.t('notifications.reminder_title'),
      body: streak > 0
          ? languageProvider
              .t('notifications.reminder_body_streak')
              .replaceAll('{days}', '$streak')
          : languageProvider.t('notifications.reminder_body'),
    );
  }

  unawaited(
    streakNotifications.initialize().then((_) => refreshStreakReminder()),
  );
  dailyStoryProvider.addListener(() => unawaited(refreshStreakReminder()));

  final collectiblesProvider = CollectiblesProvider();
  await collectiblesProvider.initialize();

  final audioPlayerProvider = AudioPlayerProvider();
  await audioPlayerProvider.initialize();

  final interactiveStoryProvider = InteractiveStoryProvider();

  // Sync de progreso: se construye al final, una vez que existen los 4
  // providers de progreso que lee/escribe. `UserProgressSyncService.instance`
  // queda disponible para que esos mismos providers empujen cambios
  // incrementales (ver sus métodos `applySynced*`/`pushXxx`) sin depender de
  // Supabase directamente. Al asignar `instance` (o si ya había sesión al
  // construirlo) dispara un `syncAll()` inicial en segundo plano.
  UserProgressSyncService.instance = UserProgressSyncService(
    client: supabaseReady ? Supabase.instance.client : null,
    auth: supabaseAuthService,
    dailyStoryProvider: dailyStoryProvider,
    collectiblesProvider: collectiblesProvider,
    readingProgressProvider: readingProgressProvider,
    interactiveStoryProvider: interactiveStoryProvider,
  );

  // Borrado de datos a petición del usuario (Ajustes → "Borrar mis datos"),
  // exigido por las tiendas. Se construye junto al sync porque necesita los
  // mismos providers de progreso, más favoritos e historial.
  final accountDataService = AccountDataService(
    client: supabaseReady ? Supabase.instance.client : null,
    auth: supabaseAuthService,
    dailyStoryProvider: dailyStoryProvider,
    readingProgressProvider: readingProgressProvider,
    collectiblesProvider: collectiblesProvider,
    interactiveStoryProvider: interactiveStoryProvider,
    favoritesProvider: favoritesProvider,
    historyProvider: historyProvider,
  );

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
        ChangeNotifierProvider.value(value: dailyStoryProvider),
        ChangeNotifierProvider.value(value: collectiblesProvider),
        ChangeNotifierProvider.value(value: audioPlayerProvider),
        ChangeNotifierProvider.value(value: interactiveStoryProvider),
        Provider.value(value: supabaseAuthService),
        Provider.value(value: accountDataService),
        Provider.value(value: streakNotifications),
        Provider.value(value: reviewPrompts),
        Provider.value(value: UserProgressSyncService.instance!),
        Provider.value(value: analytics),
      ],
      child: const PeruEternoApp(),
    ),
  );

  await HomeWidgetService.initialize(
    navigatorKey: AppNavigation.navigatorKey,
    dailyStoryProvider: dailyStoryProvider,
  );
}
