import '../models/era_model.dart';
import '../core/constants/app_colors.dart';

class ErasRepository {
  static const List<EraModel> allEras = [
    EraModel(
      id: 'caral',
      isPremium: false,
      imageFilenames: [
        'caral_1.jpg',
        'caral_2.jpg',
        'caral_3.jpg',
        'caral_4.jpg',
        'caral_5.jpg',
      ],
      accentColor: AppColors.caralColor,
      sortOrder: 0,
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
    ),
  ];
}
