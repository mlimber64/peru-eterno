# Peru Eterno — Flutter App

App de historia del Perú con 7 eras históricas, sistema trilingüe (IT/ES/EN) y modelo freemium.

## Requisitos

- Flutter 3.10+
- Dart 3.0+
- Android Studio / VS Code

## Instalación

```bash
flutter pub get
flutter run
```

## Estructura del proyecto

```
lib/
├── app.dart                           # App root widget + tema
├── main.dart                          # Entry point con providers
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Paleta tierra (ocre, terracota...)
│   │   └── app_text_styles.dart       # Tipografías (Playfair Display + Lato)
│   └── services/
│       └── localization_service.dart  # Carga JSON de i18n
├── models/
│   └── era_model.dart                 # Modelo de era histórica
├── providers/
│   ├── language_provider.dart         # Estado del idioma (IT/ES/EN)
│   └── premium_provider.dart          # Estado del desbloqueo premium
├── data/
│   └── eras_repository.dart           # Definición de las 7 eras
├── screens/
│   ├── splash_screen.dart             # Pantalla de bienvenida
│   ├── home_screen.dart               # Timeline cronológico principal
│   ├── era_detail_screen.dart         # Detalle de cada era
│   ├── gallery_screen.dart            # Galería de ilustraciones
│   └── premium_screen.dart            # Pantalla de desbloqueo (2.99€)
└── widgets/
    ├── era_timeline_card.dart         # Card de era en la timeline
    ├── image_with_fallback.dart       # Imagen con placeholder de color
    ├── language_selector_button.dart  # Botón selector de idioma
    └── premium_lock_overlay.dart      # Candado visual sobre eras premium

assets/
├── i18n/
│   ├── it.json          # Italiano (idioma principal)
│   ├── es.json          # Español
│   └── en.json          # Inglés
└── images/
    ├── caral/           prompts.md + caral_1..5.png
    ├── moche/           prompts.md + moche_1..5.png
    ├── tiahuanaco/      prompts.md + tiahuanaco_1..5.png
    ├── inca/            prompts.md + inca_1..5.png
    ├── conquista/       prompts.md + conquista_1..5.png
    ├── virreinato/      prompts.md + virreinato_1..5.png
    └── independencia/   prompts.md + independencia_1..5.png
```

## Modelo Freemium

| Era | Período | Acceso |
|-----|---------|--------|
| Caral | 3000 a.C. | Gratis |
| Moche | 100-800 d.C. | Gratis |
| Tiahuanaco | 500-1100 d.C. | Gratis |
| Imperio Inca | 1438-1533 | Premium |
| Conquista Española | 1532-1572 | Premium |
| Virreinato | 1542-1821 | Premium |
| Independencia | 1821 | Premium |

**Precio sugerido: 2.99€** — modificar en `assets/i18n/*.json` → clave `premium.price`

## Agregar ilustraciones IA

1. Abre `assets/images/<era>/prompts.md` y copia el prompt de la imagen deseada
2. Pégalo en **Midjourney** o **Leonardo AI** (modelo "Leonardo Diffusion XL")
3. Tamaño recomendado: **1200×800px** (landscape) o **800×1200px** (portrait)
4. Exporta como PNG
5. Renombra: `caral_1.png`, `caral_2.png`, etc.
6. Coloca en la carpeta correspondiente: `assets/images/caral/`
7. Hot reload o `flutter run` — aparecen automáticamente sin cambiar código

El widget `ImageWithFallback` carga desde assets y muestra un placeholder de color si la imagen no existe todavía.

## Idiomas

El idioma por defecto es **italiano**. Todos los textos históricos están en:

- `assets/i18n/it.json` — Italiano (principal)
- `assets/i18n/es.json` — Español
- `assets/i18n/en.json` — Inglés

Para editar contenido histórico: modifica `eras.<era_id>.description` en los JSON.

Para agregar un idioma nuevo:
1. Crea `assets/i18n/fr.json` copiando la estructura de `it.json`
2. Agrega `{'code': 'fr', 'label': 'Français', 'flag': '🇫🇷'}` en `LanguageProvider.supportedLanguages`
3. Agrega `- assets/i18n/` en `pubspec.yaml` (ya está declarado el directorio)

## Integrar IAP real (producción)

El botón actualmente desbloquea directamente (demo). Para producción:

1. Agrega `in_app_purchase: ^3.1.0` al `pubspec.yaml`
2. En `PremiumProvider.unlockPremium()`, implementa el flujo IAP
3. Configura el producto en Google Play Console / App Store Connect con ID `peru_eterno_premium`

## Paleta de colores

| Variable | Hex | Uso |
|----------|-----|-----|
| `AppColors.ocre` | `#C8860A` | Acentos principales, botones |
| `AppColors.terracota` | `#C1440E` | Moche, acciones secundarias |
| `AppColors.verdeAndino` | `#2D6A4F` | Independencia, badges gratis |
| `AppColors.cremaPergamino` | `#F5E6C8` | Texto sobre fondos oscuros |
| `AppColors.marronOscuro` | `#3E1C00` | AppBar, fondos, splash |
| `AppColors.bgColor` | `#F9F0DC` | Fondo principal |

## Build producción

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requiere Mac)
flutter build ios --release
```
