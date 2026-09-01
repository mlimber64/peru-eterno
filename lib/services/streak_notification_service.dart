import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio diario para no perder la racha de lectura.
///
/// Es la pieza que le faltaba a todo el sistema de rachas: había racha,
/// congelador y widget de inicio, pero nada que trajera al usuario de vuelta
/// al día siguiente. Una racha de la que nadie se acuerda no retiene a nadie.
///
/// Reglas de convivencia, para que el recordatorio no acabe siendo el motivo
/// de desinstalar la app:
///
///   · Una sola notificación al día, a una hora fija.
///   · Si ya leyó la historia de hoy, no se envía nada.
///   · Se puede desactivar desde Ajustes, y esa decisión se respeta.
///   · No se pide el permiso al arrancar por primera vez: se pide cuando el
///     usuario activa el recordatorio, que es cuando la petición tiene
///     sentido y por eso se acepta mucho más.
class StreakNotificationService {
  /// Hora local del recordatorio. Las 20:00 es cuando la gente tiene el
  /// móvil en la mano y un rato libre.
  static const int reminderHour = 20;
  static const int reminderMinute = 0;

  static const int _notificationId = 1001;
  static const String _channelId = 'streak_reminder';
  static const String _kEnabled = 'streak_reminder_enabled';

  final FlutterLocalNotificationsPlugin _plugin;
  SharedPreferences? _prefs;
  bool _initialized = false;

  StreakNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// `true` si el usuario tiene activado el recordatorio.
  ///
  /// Arranca en `false`: nadie recibe notificaciones sin haberlas pedido.
  bool get isEnabled => _prefs?.getBool(_kEnabled) ?? false;

  /// Prepara el plugin y las zonas horarias. Nunca lanza: si algo falla, el
  /// resto de la app no se entera y simplemente no hay recordatorios.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      tz_data.initializeTimeZones();

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // El permiso se pide al activar el recordatorio, no al arrancar.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (e, s) {
      if (kDebugMode) debugPrint('StreakNotificationService.initialize: $e\n$s');
    }
  }

  /// Activa el recordatorio: pide permiso y, si lo dan, programa el aviso.
  ///
  /// Devuelve `false` si el usuario negó el permiso, para que Ajustes pueda
  /// dejar el interruptor apagado en vez de mentir diciendo que está activo.
  Future<bool> enable({required bool alreadyReadToday}) async {
    await initialize();
    if (!_initialized) return false;

    final granted = await _requestPermission();
    if (!granted) return false;

    await _prefs?.setBool(_kEnabled, true);
    await refresh(alreadyReadToday: alreadyReadToday);
    return true;
  }

  Future<void> disable() async {
    await initialize();
    await _prefs?.setBool(_kEnabled, false);
    await _cancel();
  }

  /// Reprograma (o cancela) el recordatorio según el estado de hoy.
  ///
  /// Se llama al arrancar y cada vez que cambia la racha: si ya leyó, no
  /// tiene sentido recordárselo esta noche.
  Future<void> refresh({
    required bool alreadyReadToday,
    String? title,
    String? body,
  }) async {
    await initialize();
    if (!_initialized || !isEnabled) return;

    await _cancel();
    if (alreadyReadToday) return;

    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: title ?? 'Perú Eterno',
        body: body ?? '',
        scheduledDate: nextReminderInstant(DateTime.now()),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Recordatorio de racha',
            channelDescription:
                'Aviso diario para no perder tu racha de lectura',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexacto a propósito: una alarma exacta requiere el permiso
        // SCHEDULE_EXACT_ALARM, que Google restringe a apps de alarmas y
        // calendario. Un recordatorio de lectura no necesita precisión de
        // segundos y así no arriesgamos la revisión de Play.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repite cada día a la misma hora.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, s) {
      if (kDebugMode) debugPrint('StreakNotificationService.refresh: $e\n$s');
    }
  }

  /// Próxima ocurrencia de la hora del recordatorio a partir de [from].
  ///
  /// Se construye en UTC a propósito: `zonedSchedule` necesita una
  /// `TZDateTime`, y averiguar el nombre de la zona del dispositivo exigiría
  /// otro plugin nativo. Como `DateTime` ya está en hora local, se calcula el
  /// instante correcto y se convierte — el momento absoluto es el mismo.
  ///
  /// El precio: si el usuario viaja a otro huso o entra el horario de verano,
  /// el aviso se desplaza hasta la siguiente reprogramación. Como se
  /// reprograma en cada arranque, se corrige solo.
  @visibleForTesting
  static tz.TZDateTime nextReminderInstant(DateTime from) {
    var target = DateTime(
      from.year,
      from.month,
      from.day,
      reminderHour,
      reminderMinute,
    );
    if (!target.isAfter(from)) {
      target = target.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(target.toUtc(), tz.UTC);
  }

  Future<bool> _requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cancel() async {
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {
      // Cancelar algo que no existe no es un problema.
    }
  }
}
