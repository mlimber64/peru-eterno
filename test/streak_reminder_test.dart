import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/services/streak_notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

// El cálculo de "próxima vez que serán las 20:00" es donde es fácil colar un
// error de un día: programarlo para una hora ya pasada haría que el aviso
// saliera al instante, justo lo que espanta a un usuario.
/// Convierte el instante programado a la hora local del sistema.
///
/// `TZDateTime.toLocal()` NO sirve aquí: devuelve la hora en la zona `local`
/// del paquete timezone, que sin `setLocalLocation` es UTC. Lo que interesa
/// comprobar es que el instante cae a las 20:00 del reloj del usuario.
DateTime _enHoraLocal(DateTime instante) =>
    DateTime.fromMillisecondsSinceEpoch(instante.millisecondsSinceEpoch)
        .toLocal();

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('nextReminderInstant cae siempre en la próxima hora del recordatorio', () {
    // Por la mañana: el aviso es esta misma tarde.
    final manana = DateTime(2026, 9, 1, 9, 30);
    final desdeManana =
        _enHoraLocal(StreakNotificationService.nextReminderInstant(manana));
    expect(desdeManana.hour, StreakNotificationService.reminderHour);
    expect(desdeManana.day, 1);
    expect(desdeManana.isAfter(manana), isTrue);

    // Ya pasada la hora: se va a mañana, no a un instante en el pasado.
    final noche = DateTime(2026, 9, 1, 22, 15);
    final desdeNoche =
        _enHoraLocal(StreakNotificationService.nextReminderInstant(noche));
    expect(desdeNoche.hour, StreakNotificationService.reminderHour);
    expect(desdeNoche.day, 2);
    expect(desdeNoche.isAfter(noche), isTrue);

    // Justo en el minuto exacto: cuenta como pasada, para no disparar el
    // aviso en el mismo segundo en que se programa.
    final justo = DateTime(2026, 9, 1, StreakNotificationService.reminderHour,
        StreakNotificationService.reminderMinute);
    final desdeJusto =
        _enHoraLocal(StreakNotificationService.nextReminderInstant(justo));
    expect(desdeJusto.day, 2);

    // Último día del mes: tiene que saltar de mes correctamente.
    final finDeMes = DateTime(2026, 9, 30, 23, 0);
    final desdeFinDeMes =
        _enHoraLocal(StreakNotificationService.nextReminderInstant(finDeMes));
    expect(desdeFinDeMes.month, 10);
    expect(desdeFinDeMes.day, 1);
  });
}
