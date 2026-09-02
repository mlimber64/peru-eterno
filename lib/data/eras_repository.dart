import '../models/era_model.dart';
import '../core/constants/app_colors.dart';

class ErasRepository {
  static const List<EraModel> allEras = [
    EraModel(
      id: 'caral',
      isPremium: false,
      // Caral es la única era cuyas imágenes no están en
      // `assets/images/caral/` (esa carpeta quedó vacía): viven junto al
      // contenido editorial. Los nombres `caral_1.jpg`…`caral_5.jpg` que
      // había aquí no existían en el bundle.
      imageFolderOverride: 'assets/images/content/caral/',
      imageFilenames: [
        'caral_desertico.webp',
        'caral_atardecer_eterno.webp',
        'caral_nocturno_astronomico.webp',
        'plaza_circular_caral.webp',
        'sacerdote_ceremonial_andino.webp',
      ],
      accentColor: AppColors.caralColor,
      sortOrder: 0,
      wikipediaSlug: {
        'es': 'Caral',
        'en': 'Caral',
        'it': 'Caral',
      },
    ),
    EraModel(
      id: 'moche',
      isPremium: false,
      imageFilenames: [
        'moche_1.jpg',
        'moche_2.jpg',
        'moche_3.jpg',
        'moche_4.jpg',
        'moche_5.jpg',
      ],
      accentColor: AppColors.mocheColor,
      sortOrder: 1,
      wikipediaSlug: {
        'es': 'Cultura_moche',
        'en': 'Moche_culture',
        'it': 'Cultura_mochica',
      },
    ),
    EraModel(
      id: 'tiahuanaco',
      isPremium: false,
      imageFilenames: [
        'tiahuanaco_1.jpg',
        'tiahuanaco_2.jpg',
        'tiahuanaco_3.jpg',
        'tiahuanaco_4.jpg',
        'tiahuanaco_5.jpg',
      ],
      accentColor: AppColors.tiahuanacoColor,
      sortOrder: 2,
      wikipediaSlug: {
        'es': 'Tiahuanaco',
        'en': 'Tiwanaku',
        'it': 'Tiwanaku',
      },
    ),
    EraModel(
      id: 'inca',
      isPremium: true,
      imageFilenames: [
        'inca_1.jpg',
        'inca_2.jpg',
        'inca_3.jpg',
        'inca_4.jpg',
        'inca_5.jpg',
      ],
      accentColor: AppColors.incaColor,
      sortOrder: 3,
      wikipediaSlug: {
        'es': 'Imperio_incaico',
        'en': 'Inca_Empire',
        'it': 'Impero_inca',
      },
    ),
    EraModel(
      id: 'conquista',
      isPremium: true,
      imageFilenames: [
        'conquista_1.jpg',
        'conquista_2.jpg',
        'conquista_3.jpg',
        'conquista_4.jpg',
        'conquista_5.jpg',
      ],
      accentColor: AppColors.conquistaColor,
      sortOrder: 4,
      wikipediaSlug: {
        'es': 'Conquista_del_Perú',
        'en': 'Spanish_conquest_of_the_Inca_Empire',
        'it': 'Conquista_del_Perù',
      },
    ),
    EraModel(
      id: 'virreinato',
      isPremium: true,
      imageFilenames: [
        'virreinato_1.jpg',
        'virreinato_2.jpg',
        'virreinato_3.jpg',
        'virreinato_4.jpg',
        'virreinato_5.jpg',
      ],
      accentColor: AppColors.virreinatoColor,
      sortOrder: 5,
      wikipediaSlug: {
        'es': 'Virreinato_del_Perú',
        'en': 'Viceroyalty_of_Peru',
        'it': 'Vicereame_del_Perù',
      },
    ),
    EraModel(
      id: 'independencia',
      isPremium: true,
      imageFilenames: [
        'independencia_1.jpg',
        'independencia_2.jpg',
        'independencia_3.jpg',
        'independencia_4.jpg',
        'independencia_5.jpg',
      ],
      accentColor: AppColors.independenciaColor,
      sortOrder: 6,
      wikipediaSlug: {
        'es': 'Independencia_del_Perú',
        'en': 'Peruvian_War_of_Independence',
        'it': 'Indipendenza_del_Perù',
      },
    ),
  ];
}
