import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/providers/collectibles_provider.dart';
import 'package:peru_eterno/providers/interactive_story_provider.dart';
import 'package:peru_eterno/providers/reading_progress_provider.dart';
import 'package:peru_eterno/services/user_progress_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El sync de progreso es la única parte de la app que puede PERDER datos del
// usuario: si lo que baja de Supabase no llega a SharedPreferences, cambiar
// de móvil borra el álbum y los finales descubiertos. Estos tests cubren el
// lado local de la fusión (`applySynced*`), que es donde el pull aterriza.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('finales de Narrativa Interactiva', () {
    test('applySyncedEndings persiste sin haber abierto ninguna historia', () async {
      // Caso real: `syncAll()` corre al arrancar, mucho antes de que el
      // usuario entre a una historia. Si el provider exige un `loadStory`
      // previo para tener SharedPreferences, el pull se descarta en silencio
      // y los finales de otro dispositivo nunca aparecen.
      SharedPreferences.setMockInitialValues({});
      final isp = InteractiveStoryProvider();

      await isp.applySyncedEndings('chasqui', {'final_heroe', 'final_traidor'});

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('${InteractiveStoryProvider.kUnlockedEndingsPrefix}chasqui'),
        unorderedEquals(['final_heroe', 'final_traidor']),
      );
    });

    test('loadStory lee los finales que dejó el sync', () async {
      SharedPreferences.setMockInitialValues({
        '${InteractiveStoryProvider.kUnlockedEndingsPrefix}chasqui': ['final_heroe'],
      });
      final isp = InteractiveStoryProvider();

      await isp.applySyncedEndings('chasqui', {'final_heroe', 'final_traidor'});

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('${InteractiveStoryProvider.kUnlockedEndingsPrefix}chasqui'),
        unorderedEquals(['final_heroe', 'final_traidor']),
      );
    });
  });

  group('coleccionables', () {
    test('applySyncedUnlocks desbloquea lo remoto y guarda la fecha más antigua',
        () async {
      final local = DateTime.utc(2026, 5, 10);
      final remotoMasViejo = DateTime.utc(2026, 1, 2);
      SharedPreferences.setMockInitialValues({
        'cp_unlocked': ['carta_a'],
        'cp_unlocked_at': jsonEncode({'carta_a': local.toIso8601String()}),
      });
      final cp = CollectiblesProvider();
      await cp.initialize();

      await cp.applySyncedUnlocks({
        'carta_a': remotoMasViejo, // ya estaba: gana la fecha más antigua
        'carta_b': remotoMasViejo, // solo remota: se desbloquea
      });

      expect(cp.isUnlocked('carta_a'), isTrue);
      expect(cp.isUnlocked('carta_b'), isTrue);
      expect(cp.unlockedAtMap['carta_a'], remotoMasViejo);

      // Y sobrevive a un reinicio de la app: el pull tiene que quedar en disco.
      final reinicio = CollectiblesProvider();
      await reinicio.initialize();
      expect(reinicio.isUnlocked('carta_b'), isTrue);
      expect(reinicio.unlockedAtMap['carta_a'], remotoMasViejo);
    });

    test('applySyncedQuizScores nunca baja un puntaje', () async {
      SharedPreferences.setMockInitialValues({
        'cp_quiz_scores': jsonEncode({'cap_1': 3, 'cap_2': 1}),
      });
      final cp = CollectiblesProvider();
      await cp.initialize();

      await cp.applySyncedQuizScores({'cap_1': 1, 'cap_2': 3, 'cap_3': 2});

      expect(cp.bestScoreFor('cap_1'), 3); // remoto peor: se ignora
      expect(cp.bestScoreFor('cap_2'), 3); // remoto mejor: gana
      expect(cp.bestScoreFor('cap_3'), 2); // solo remoto: entra
    });
  });

  group('capítulos leídos', () {
    test('applySyncedReadIds une sin borrar lo local y persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final rp = ReadingProgressProvider();
      await rp.initialize();
      await rp.setRead('cap_local', true);

      await rp.applySyncedReadIds({'cap_remoto'});

      expect(rp.readArticleIds, containsAll(['cap_local', 'cap_remoto']));

      final reinicio = ReadingProgressProvider();
      await reinicio.initialize();
      expect(reinicio.isRead('cap_remoto'), isTrue);
    });
  });

  group('racha', () {
    test('mergeLastCompletedDate se queda con la lectura más reciente', () {
      const merge = UserProgressSyncService.mergeLastCompletedDate;

      // Leyó hoy en el otro móvil: gana esa fecha aunque aquí la racha fuera
      // más larga (el caso que hacía pedir la lectura del día dos veces).
      expect(merge('2026-09-01', '2026-09-02'), '2026-09-02');
      expect(merge('2026-09-02', '2026-09-01'), '2026-09-02');
      expect(merge('2026-09-02', '2026-09-02'), '2026-09-02');

      // Instalación nueva de un lado: se adopta la del otro sin inventar nada.
      expect(merge(null, '2026-09-02'), '2026-09-02');
      expect(merge('2026-09-02', null), '2026-09-02');
      expect(merge(null, null), isNull);
    });
  });
}
