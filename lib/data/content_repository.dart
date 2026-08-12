import '../models/content_item.dart';
import '../models/era_model.dart';
import 'eras_repository.dart';

class ContentRepository {
  // ── Historia (eras) ──────────────────────────────────────────────────────
  // Las eras viven únicamente en ErasRepository (fuente única de verdad).
  // `_eraAsContentItem` es el único puente restante: existe solo para que
  // `all`/`findById` sigan resolviendo ids de era como ContentItem genérico,
  // que es lo que aún necesitan consumidores fuera de este refactor (p. ej.
  // CulturalMapScreen, que abre ContentDetailScreen para algunos puntos de
  // era). La UI que arma listas mixtas usa ErasRepository.allEras
  // directamente (ver ContentRef) y ya no pasa por aquí.
  static ContentItem _eraAsContentItem(EraModel era) => ContentItem(
        id: era.id,
        category: 'era',
        wikipediaSlug: era.wikipediaSlug,
        isPremium: era.isPremium,
      );

  // ── Personajes ilustres ───────────────────────────────────────────────────
  static const List<ContentItem> personajes = [
    ContentItem(id: 'cesar_vallejo', category: 'personaje', wikipediaSlug: {
      'es': 'César_Vallejo', 'en': 'César_Vallejo', 'it': 'César_Vallejo',
    }),
    ContentItem(id: 'chabuca_granda', category: 'personaje', wikipediaSlug: {
      'es': 'Chabuca_Granda', 'en': 'Chabuca_Granda', 'it': 'Chabuca_Granda',
    }),
    ContentItem(id: 'vargas_llosa', category: 'personaje', wikipediaSlug: {
      'es': 'Mario_Vargas_Llosa',
      'en': 'Mario_Vargas_Llosa',
      'it': 'Mario_Vargas_Llosa',
    }),
    ContentItem(id: 'ricardo_palma', category: 'personaje', wikipediaSlug: {
      'es': 'Ricardo_Palma', 'en': 'Ricardo_Palma', 'it': 'Ricardo_Palma',
    }),
    ContentItem(id: 'arguedas', category: 'personaje', wikipediaSlug: {
      'es': 'José_María_Arguedas',
      'en': 'José_María_Arguedas',
      'it': 'José_María_Arguedas',
    }),
    ContentItem(id: 'tupac_amaru', category: 'personaje', wikipediaSlug: {
      'es': 'Túpac_Amaru_II', 'en': 'Túpac_Amaru_II', 'it': 'Túpac_Amaru_II',
    }),
    ContentItem(id: 'pachacutec', category: 'personaje', wikipediaSlug: {
      'es': 'Pachacútec', 'en': 'Pachacuti', 'it': 'Pachacuti',
    }),
    ContentItem(id: 'carrion', category: 'personaje', wikipediaSlug: {
      'es': 'Daniel_Alcides_Carrión',
      'en': 'Daniel_Alcides_Carrión',
      'it': 'Daniel_Alcides_Carrión',
    }),
    ContentItem(id: 'bolognesi', category: 'personaje', wikipediaSlug: {
      'es': 'Francisco_Bolognesi',
      'en': 'Francisco_Bolognesi',
      'it': 'Francisco_Bolognesi',
    }),
  ];

  // ── Costumbres y tradiciones ──────────────────────────────────────────────
  static const List<ContentItem> tradiciones = [
    ContentItem(id: 'inti_raymi', category: 'tradicion', wikipediaSlug: {
      'es': 'Inti_Raymi', 'en': 'Inti_Raymi', 'it': 'Inti_Raymi',
    }),
    ContentItem(id: 'marinera', category: 'tradicion', wikipediaSlug: {
      'es': 'Marinera_(danza)',
      'en': 'Marinera_(dance)',
      'it': 'Marinera_(danza)',
    }),
    ContentItem(id: 'pachamama', category: 'tradicion', wikipediaSlug: {
      'es': 'Pachamama', 'en': 'Pachamama', 'it': 'Pachamama',
    }),
    ContentItem(id: 'semana_santa_ayacucho', category: 'tradicion', wikipediaSlug: {
      'es': 'Semana_Santa_en_Ayacucho',
      'en': 'Holy_Week_in_Ayacucho',
      'it': 'Settimana_Santa_di_Ayacucho',
    }),
  ];

  // ── Gastronomía ───────────────────────────────────────────────────────────
  static const List<ContentItem> gastronomia = [
    ContentItem(id: 'ceviche', category: 'gastronomia', wikipediaSlug: {
      'es': 'Ceviche', 'en': 'Ceviche', 'it': 'Ceviche',
    }),
    ContentItem(id: 'lomo_saltado', category: 'gastronomia', wikipediaSlug: {
      'es': 'Lomo_saltado', 'en': 'Lomo_saltado', 'it': 'Lomo_saltado',
    }),
    ContentItem(id: 'aji_de_gallina', category: 'gastronomia', wikipediaSlug: {
      'es': 'Ají_de_gallina', 'en': 'Ají_de_gallina', 'it': 'Ají_de_gallina',
    }),
    ContentItem(id: 'chicha_morada', category: 'gastronomia', wikipediaSlug: {
      'es': 'Chicha_morada', 'en': 'Chicha_morada', 'it': 'Chicha_morada',
    }),
    ContentItem(id: 'pisco_sour', category: 'gastronomia', wikipediaSlug: {
      'es': 'Pisco_sour', 'en': 'Pisco_sour', 'it': 'Pisco_sour',
    }),
    ContentItem(id: 'pachamanca', category: 'gastronomia', wikipediaSlug: {
      'es': 'Pachamanca', 'en': 'Pachamanca', 'it': 'Pachamanca',
    }),
  ];

  // ── Música y danzas ───────────────────────────────────────────────────────
  static const List<ContentItem> musica = [
    ContentItem(id: 'huayno', category: 'musica', wikipediaSlug: {
      'es': 'Huayno', 'en': 'Huayno', 'it': 'Huayno',
    }),
    ContentItem(id: 'vals_criollo', category: 'musica', wikipediaSlug: {
      'es': 'Música_criolla', 'en': 'Peruvian_waltz', 'it': 'Valzer_criollo',
    }),
    ContentItem(id: 'festejo', category: 'musica', wikipediaSlug: {
      'es': 'Festejo', 'en': 'Festejo', 'it': 'Festejo',
    }),
    ContentItem(id: 'cajon', category: 'musica', wikipediaSlug: {
      'es': 'Cajón', 'en': 'Cajón', 'it': 'Cajón',
    }),
  ];

  // ── Geografía ─────────────────────────────────────────────────────────────
  static const List<ContentItem> geografia = [
    ContentItem(id: 'andes', category: 'geografia', wikipediaSlug: {
      'es': 'Cordillera_de_los_Andes', 'en': 'Andes', 'it': 'Ande',
    }),
    ContentItem(id: 'amazonia', category: 'geografia', wikipediaSlug: {
      'es': 'Amazonía_peruana', 'en': 'Peruvian_Amazon', 'it': 'Amazzonia_peruviana',
    }),
    ContentItem(id: 'machu_picchu', category: 'geografia', wikipediaSlug: {
      'es': 'Machu_Picchu', 'en': 'Machu_Picchu', 'it': 'Machu_Picchu',
    }),
    ContentItem(id: 'lago_titicaca', category: 'geografia', wikipediaSlug: {
      'es': 'Lago_Titicaca', 'en': 'Lake_Titicaca', 'it': 'Lago_Titicaca',
    }),
  ];

  static List<ContentItem> get all => [
        ...ErasRepository.allEras.map(_eraAsContentItem),
        ...personajes,
        ...tradiciones,
        ...gastronomia,
        ...musica,
        ...geografia,
      ];

  static ContentItem? findById(String id) {
    try {
      return all.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
