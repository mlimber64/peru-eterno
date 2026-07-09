/// Atribuciones de imágenes y fuentes para la pantalla "Fonti e Crediti".
///
/// Cumple los requisitos de las licencias (Wikimedia Commons / Creative
/// Commons) y documenta el origen de cada recurso visual de la app.
library;

enum CreditLicense {
  publicDomain, // Dominio público / CC0
  ccBySa4, // Creative Commons BY-SA 4.0 (requiere atribución)
  ccBySa3, // Creative Commons BY-SA 3.0
  ccBySa2, // Creative Commons BY-SA 2.0
  ccBy3, // Creative Commons BY 3.0
  aiGenerated, // Generada con inteligencia artificial
}

class ImageCredit {
  final String title; // Nombre de la figura / obra
  final String author; // Autor o fuente
  final String year; // Año aproximado
  final CreditLicense license;
  final String? sourceUrl; // Página de origen (null para imágenes IA)

  const ImageCredit({
    required this.title,
    required this.author,
    required this.year,
    required this.license,
    this.sourceUrl,
  });
}

class CreditsData {
  CreditsData._();

  /// Imágenes de personajes — fotografías/retratos de fuentes públicas.
  static const List<ImageCredit> personajes = [
    ImageCredit(
      title: 'César Vallejo',
      author: 'Juan Domingo Córdoba',
      year: '1929',
      license: CreditLicense.publicDomain,
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Cesar_vallejo_1929.jpg',
    ),
    ImageCredit(
      title: 'Chabuca Granda',
      author: 'Annemarie Heinrich',
      year: '1966',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Chabuca_Granda_by_Annemarie_Heinrich,_1966.jpg',
    ),
    ImageCredit(
      title: 'Mario Vargas Llosa',
      author: 'Bernard Gotfryd · Library of Congress',
      year: '1986',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Mario_Vargas_Llosa_LCCN2020733847_(cropped).png',
    ),
    ImageCredit(
      title: 'Ricardo Palma',
      author: 'Manuel Moral y Vega',
      year: '1910',
      license: CreditLicense.publicDomain,
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Palma1.jpg',
    ),
    ImageCredit(
      title: 'José María Arguedas',
      author: 'Autore sconosciuto',
      year: '< 1969',
      license: CreditLicense.ccBySa4,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Jos%C3%A9_Mar%C3%ADa_Arguedas_en_Chaclacayo,_Lima,_Per%C3%BA.jpg',
    ),
    ImageCredit(
      title: 'Túpac Amaru II',
      author: 'Acquerello anonimo',
      year: 'c. 1784–1806',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Acuarela_de_T%C3%BApac_Amaru_II_crop.jpg',
    ),
    ImageCredit(
      title: 'Pachacútec',
      author: 'Felipe Guamán Poma de Ayala',
      year: 'c. 1615',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Portrait_of_Pachacutic,_9th_Shapa_Inka_(1438%E2%80%931471),_1615.jpg',
    ),
    ImageCredit(
      title: 'Daniel Alcides Carrión',
      author: 'Eugenio Courret',
      year: 'c. 1880',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Daniel_Alcides_Carr%C3%ADon_Garc%C3%ADa.jpg',
    ),
    ImageCredit(
      title: 'Francisco Bolognesi',
      author: 'Fotografo anonimo',
      year: '1864',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Francisco_Bolognesi_1864.jpg',
    ),
  ];

  /// Imágenes de gastronomía — fotografías de fuentes públicas.
  static const List<ImageCredit> gastronomia = [
    ImageCredit(
      title: 'Ceviche',
      author: 'ProjectManhattan',
      year: '2011',
      license: CreditLicense.publicDomain,
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ceviche_at_Peru.jpg',
    ),
    ImageCredit(
      title: 'Lomo saltado',
      author: 'Shoestring',
      year: '2009',
      license: CreditLicense.ccBySa4,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Lomo_Saltado,_Lima,_Peru.JPG',
    ),
    ImageCredit(
      title: 'Ají de gallina',
      author: 'Feralbt',
      year: '2011',
      license: CreditLicense.ccBySa3,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Aj%C3%AD_de_gallina.jpg',
    ),
    ImageCredit(
      title: 'Chicha morada',
      author: 'Dtarazona',
      year: '2008',
      license: CreditLicense.publicDomain,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Chicha_morada_(olla).JPG',
    ),
    ImageCredit(
      title: 'Pisco sour',
      author: 'Dtarazona',
      year: '2010',
      license: CreditLicense.ccBySa4,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Pisco_sour_20100613b.JPG',
    ),
    ImageCredit(
      title: 'Pachamanca',
      author: 'PromPerú',
      year: '2021',
      license: CreditLicense.ccBy3,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Pachamanca_by_Promper%C3%BA.png',
    ),
  ];

  /// Imágenes de geografía — fotografías de paisajes de fuentes públicas.
  static const List<ImageCredit> geografia = [
    ImageCredit(
      title: 'Ande (Alpamayo)',
      author: 'Frank R 1981',
      year: '2012',
      license: CreditLicense.ccBySa4,
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Alpamayo_12.jpg',
    ),
    ImageCredit(
      title: 'Amazzonia (Tambopata)',
      author: 'Alexey Yakovlev',
      year: '2008',
      license: CreditLicense.ccBySa2,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Tambopata_RainForest_(2868296103).jpg',
    ),
    ImageCredit(
      title: 'Machu Picchu',
      author: 'Pedro Szekely',
      year: '2007',
      license: CreditLicense.ccBySa2,
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Machu_Picchu,_Peru.jpg',
    ),
    ImageCredit(
      title: 'Lago Titicaca (Uros)',
      author: 'Diego Delso',
      year: '2015',
      license: CreditLicense.ccBySa4,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Islas_flotantes_de_los_Uros,_Lago_Titicaca,_Per%C3%BA,_2015-08-01,_DD_36.JPG',
    ),
  ];

  /// Imágenes de música — foto del cajón (real) + escenas de géneros (IA).
  static const List<ImageCredit> musica = [
    ImageCredit(
      title: 'Cajón peruano',
      author: 'SLR (Soulecito)',
      year: '2009',
      license: CreditLicense.ccBy3,
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Cajon_peruano._Instrumento_de_percusi%C3%B3n.JPG',
    ),
    ImageCredit(
      title: 'Huayno',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
    ImageCredit(
      title: 'Vals Criollo',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
    ImageCredit(
      title: 'Festejo',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
  ];

  /// Imágenes de las etapas históricas — generadas con IA.
  static const List<ImageCredit> etapas = [
    ImageCredit(
      title: 'Perù preispanico',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
    ImageCredit(
      title: 'Conquista spagnola',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
    ImageCredit(
      title: 'Vicereame del Perù',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
    ImageCredit(
      title: 'Indipendenza',
      author: 'Perú Eterno',
      year: '2026',
      license: CreditLicense.aiGenerated,
    ),
  ];
}
