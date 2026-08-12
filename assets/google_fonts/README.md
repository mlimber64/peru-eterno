# Fuentes bundleadas (Lato + Playfair Display)

Estos `.ttf` se sirven localmente en vez de por red (`GoogleFonts.config.allowRuntimeFetching = false` en `main.dart`), para que la app no dependa de internet en el primer arranque ni haga una request a Google por cada instalación.

El paquete `google_fonts` busca automáticamente estos archivos por nombre exacto (`{Familia}-{Variante}.ttf`) entre los assets declarados — no requiere tocar la sección `fonts:` de `pubspec.yaml`, solo declarar la carpeta como asset (ya hecho).

## Cómo se generaron

Cada archivo es el `.ttf` estático oficial servido por `fonts.googleapis.com/css2`, obtenido así (reemplazar pesos/family según se necesite):

```
curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/534.34 (KHTML, like Gecko) PhantomJS/1.9.7 Safari/534.34" \
  "https://fonts.googleapis.com/css2?family=Lato:ital,wght@0,100;0,300;0,400;0,700;0,900;1,100;1,300;1,400;1,700;1,900&display=swap"
```

El User-Agent "viejo" es necesario: con un User-Agent moderno, Google devuelve `.woff2` en vez de `.ttf`, que es lo que `google_fonts` espera.

## Pesos incluidos

- **Lato**: Thin(100), Light(300), Regular(400), Bold(700), Black(900) — normal + italic (los únicos pesos que existen para esta familia; cualquier `FontWeight` intermedio pedido en el código, ej. w600, resuelve al más cercano de estos).
- **Playfair Display**: Regular(400), Medium(500), SemiBold(600), Bold(700), ExtraBold(800), Black(900) normal; Regular(400) y Bold(700) italic.

Si se agrega un uso nuevo de `GoogleFonts.playfairDisplay(fontWeight: ..., fontStyle: ...)` con una combinación de peso/italic no cubierta arriba, `google_fonts` cae de vuelta al *closest match* disponible — no rompe, pero el peso visual puede no ser exacto. Si eso pasa, agregar el `.ttf` que falte con el mismo método.
