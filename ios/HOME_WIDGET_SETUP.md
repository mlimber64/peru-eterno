# Home Screen Widget en iOS — pasos pendientes en Xcode

El lado Dart ya está listo (`lib/services/home_widget_service.dart` llama
`HomeWidget.setAppGroupId('group.com.perueternno.peru_eterno')` y publica los
mismos datos que usa el widget de Android). Falta lo que **solo se puede
hacer desde Xcode** — no es seguro generar esto editando archivos de texto a
ciegas, ya que requiere crear un target nuevo en `project.pbxproj`.

## 1. Habilitar App Groups

1. Abrir `ios/Runner.xcworkspace` en Xcode.
2. Seleccionar el target **Runner** → pestaña *Signing & Capabilities* → `+
   Capability` → **App Groups**.
3. Agregar el grupo `group.com.perueternno.peru_eterno` (mismo id que en
   `HomeWidgetService._appGroupId`).

## 2. Crear el target de Widget Extension

1. `File` → `New` → `Target...` → **Widget Extension** (elegir "Include
   Configuration Intent" = No). Nombre sugerido: `DailyFactWidget`.
2. En el nuevo target, repetir el paso 1 (App Groups) con el mismo id.
3. Reemplazar el `TimelineProvider` generado por uno que lea los datos
   guardados por `HomeWidget.saveWidgetData` desde el App Group compartido:

   ```swift
   let userDefaults = UserDefaults(suiteName: "group.com.perueternno.peru_eterno")
   let title = userDefaults?.string(forKey: "daily_title") ?? "Perú Eterno"
   let calloutHeader = userDefaults?.string(forKey: "daily_callout_header") ?? "¿SABÍAS QUÉ?"
   let calloutBody = userDefaults?.string(forKey: "daily_callout_body") ?? ""
   ```

4. Diseñar la vista SwiftUI del widget reutilizando esos tres campos (mismo
   contenido que `android/app/src/main/res/layout/daily_fact_widget.xml`:
   eyebrow "HISTORIA DEL DÍA", título, "¿Sabías qué?" + cuerpo).

## 3. Deep link al tocar el widget

En la vista del widget, envolver el contenido en:

```swift
.widgetURL(URL(string: "peruEterno://dailyStory"))
```

Y en `Runner/Info.plist` agregar el esquema de URL:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>peruEterno</string>
    </array>
  </dict>
</array>
```

`home_widget` intercepta esa URL automáticamente y la entrega por
`HomeWidget.widgetClicked` / `HomeWidget.initiallyLaunchedFromHomeWidget()`
igual que en Android — no hace falta tocar código Dart adicional.

## 4. Refrescar el widget desde Dart

Ya está cubierto: `HomeWidgetService.updateData` llama
`HomeWidget.updateWidget(androidName: 'DailyFactWidgetProvider')`. Para que
también refresque en iOS, agregar el nombre del widget de iOS:

```dart
await HomeWidget.updateWidget(
  androidName: 'DailyFactWidgetProvider',
  iOSName: 'DailyFactWidget', // debe coincidir con el nombre del target/kind
);
```
