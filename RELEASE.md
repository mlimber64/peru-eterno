# Publicación — Perú Eterno

Guía operativa para pasar de "compila en mi máquina" a "está en Google Play".
Cada sección es un paso que **bloquea** la publicación si falta.

---

## 1. Crear el keystore de release

Sin esto, `flutter build` **no falla**: cae silenciosamente a la firma de
debug (ver `android/app/build.gradle.kts`) y Play rechaza el artefacto al
subirlo.

```bash
keytool -genkey -v \
  -keystore C:/Users/limbe/keys/peru-eterno-upload.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Te preguntará dos contraseñas (store y clave) y tus datos. Después:

```bash
cp android/key.properties.example android/key.properties
```

Y rellena `android/key.properties` con esos valores. En Windows escribe la
ruta con barras normales: `C:/Users/limbe/keys/peru-eterno-upload.jks`.

> **Guarda ese .jks y sus contraseñas fuera del repo y con copia de
> seguridad.** Si lo pierdes, no puedes publicar actualizaciones de la misma
> app nunca más — hay que crear una ficha nueva. `.gitignore` ya excluye
> `key.properties`, `*.jks` y `*.keystore`.

Al crear la app en Play Console, activa **Play App Signing** (viene activado
por defecto): Google guarda la clave de firma final y tu `.jks` pasa a ser
solo la clave de *subida*, que sí se puede reemplazar si se pierde.

---

## 2. Secretos de compilación

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `EUROPEANA_API_KEY` se leen con
`String.fromEnvironment`: son constantes de **compilación**. Un binario
construido sin ellas queda en modo 100% local de forma permanente; no se
activan después.

```bash
cp env.example.json env.json   # env.json ya está en .gitignore
```

Rellena los valores reales y compila siempre con
`--dart-define-from-file=env.json` (el script del paso 4 lo hace por ti).

---

## 3. Backend (Supabase)

En el proyecto de Supabase, ejecutar en el SQL Editor **en este orden**:

1. `supabase/migrations/20260812_user_progress.sql` (ya aplicada).
2. `supabase/migrations/20260901_data_deletion.sql` — **pendiente**. Añade
   las policies de `DELETE` sin las cuales "Borrar mis datos" no puede tocar
   el servidor, y deja lista la función de purga de cuentas inactivas.

Opcional pero recomendado, para que el borrado elimine también el usuario de
`auth.users` (y no solo sus filas):

```bash
supabase functions deploy delete-account
```

La app funciona sin esa función: cae al borrado de filas vía RLS.

### Correo de vinculación de cuenta — **pendiente y bloqueante**

La pantalla «Guarda tu progreso» envía un código de 6 dígitos por correo, y hoy
**no puede funcionar todavía**. Hacen falta dos cosas, en este orden:

1. **SMTP propio** en Project Settings → Authentication → SMTP Settings.
   Supabase bloquea la edición de plantillas hasta tenerlo ("Set up custom SMTP
   to edit templates"), y su servicio integrado no sirve para producción.
2. **Plantillas** de `supabase/email_templates/` pegadas en Authentication →
   Emails (las dos: *Magic link or OTP* y *Change Email Address*). Las de por
   defecto mandan solo un enlace, sin el `{{ .Token }}` que el usuario tiene
   que teclear.

Sin dominio propio, Brevo permite verificar una sola dirección como remitente.
Con dominio, Resend es más cómodo y mejora la entrega. Detalle en
`supabase/email_templates/README.md`.

---

## 4. Construir el App Bundle

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
```

El script verifica keystore y secretos **antes** de compilar, y deja el
bundle en `build/app/outputs/bundle/release/app-release.aab`. Añade `-Apk`
si además quieres un APK universal para probar en un dispositivo real.

Verificar con qué clave quedó firmado:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

---

## 5. Publicar las páginas legales

Play Console exige una **URL pública** de la política de privacidad (además
de la pantalla dentro de la app, que ya existe en Ajustes → Legal).

1. `dart run tool/generate_legal_html.dart` (regenera `docs/` desde
   `assets/legal/legal.json`, que es la única fuente del texto).
2. Commitea `docs/`.
3. GitHub → **Settings → Pages** → Source: *Deploy from a branch*, branch
   `main`, carpeta `/docs`.
4. URLs resultantes:
   - <https://mlimber64.github.io/peru-eterno/privacy.html>
   - <https://mlimber64.github.io/peru-eterno/terms.html>

> El repositorio debe ser **público** para servir Pages en el plan gratuito.
> Si prefieres mantenerlo privado, sube esos dos HTML a cualquier hosting y
> usa esa URL en su lugar.

**Antes de publicar**: el email de contacto que aparece en ambos documentos
es `perueterno.app@gmail.com` y está definido en un único sitio,
`assets/legal/legal.json` → `contact_email`. Créalo o cámbialo ahí (y vuelve
a generar el HTML).

---

## 6. Ficha de Play Console

### Antes de crear la cuenta de desarrollador

El **país de la cuenta y de su perfil de pagos se fija al crearla y no se puede
cambiar**: equivocarse obliga a abrir otra cuenta y volver a pagar los 25 USD.
El responsable reside en **Italia**, así que la cuenta se registra allí — es
también lo que declaran la política de privacidad y los términos (autoridad de
control: Garante per la protezione dei dati personali; ley aplicable: italiana).

Google pedirá verificación de identidad con dirección italiana y datos fiscales
para el perfil de pagos. Vender suscripciones de forma continuada es actividad
económica: conviene resolver el encaje fiscal (partita IVA y régimen) con un
*commercialista* antes de registrarse.

### Seguridad de los datos (Data safety)

Respuestas que corresponden a lo que la app hace hoy:

| Pregunta | Respuesta |
|---|---|
| ¿Recopila datos? | Sí |
| Tipo | *App activity → App interactions* y *App info and performance → Other* (progreso de lectura, racha, puntajes) |
| ¿Identificadores? | Sí: identificador de usuario anónimo generado por la app |
| ¿Se comparten con terceros? | No |
| ¿Están cifrados en tránsito? | Sí (HTTPS) |
| ¿Dónde se alojan? | Unión Europea — Supabase, región Europa Central (Frankfurt) |
| *App activity → Other* | Correo electrónico, **solo si el usuario vincula su cuenta** (opcional) |
| *App info and performance → Crash logs* | Sí — informes de error a nuestro propio servidor, sin SDK de terceros |
| ¿El usuario puede solicitar el borrado? | **Sí** — Ajustes → Borrar mis datos |
| ¿Publicidad? | No |
| ¿Datos de menores? | No dirigida a menores de 13 |

En **Eliminación de datos y de la cuenta** hay que indicar que existe la vía
in-app (Ajustes → Borrar mis datos) y dar la URL de la política, que explica
también la vía por email.

### Suscripciones

Los IDs de producto deben coincidir **exactamente** con los del código
(`lib/providers/premium_provider.dart`):

- `peru_eterno_premium_weekly`
- `peru_eterno_premium_annual`

Si no existen en Play Console con esos IDs, el paywall mostrará
"tienda no disponible" y no se podrá comprar.

#### La prueba gratuita: configúrala como oferta de Play

La app trae una prueba de 7 días propia. Con la migración
`20260901_entitlements.sql` aplicada, el "ya la usaste" se guarda en el
servidor en vez de en el dispositivo, pero **solo sobrevive a una
reinstalación si el usuario vinculó su cuenta a un correo**: con una sesión
anónima nueva, vuelve a tener derecho a prueba.

El cierre definitivo es configurarla en Play Console como **oferta de prueba
gratuita del plan base** (Monetización → Suscripciones → tu plan → Ofertas).
Google la asocia a la cuenta de Google del usuario, que sobrevive a cualquier
reinstalación o cambio de teléfono. Es además lo que hace la competencia,
porque obliga a introducir método de pago y convierte mucho mejor.

Si se hace así, el botón "Prueba gratis 7 días" del paywall debe pasar a
lanzar la compra normal (Play ya muestra "7 días gratis, luego X €") en vez de
llamar a `startFreeTrial()`. Es un cambio pequeño en `premium_screen.dart`,
pendiente de decidir.

#### Validación de compras en servidor

La Edge Function `verify-purchase` contrasta cada recibo con la API de Google
Play antes de conceder el acceso, y guarda la fecha de expiración que dice
Google — no una calculada con el reloj del teléfono. Para activarla:

1. En Google Cloud, crea un **service account** y descarga su JSON.
2. Vincula el proyecto de Cloud con Play Console (Configuración → Acceso a la
   API) y da a ese service account permiso para **ver datos financieros** y
   **gestionar pedidos y suscripciones**.
3. Carga los secretos y despliega:

   ```bash
   supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=com.perueternno.peru_eterno
   supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat service-account.json)"
   supabase functions deploy verify-purchase
   supabase functions deploy start-trial
   ```

Sin esos secretos la función responde 501 y la app concede el acceso en local,
como antes. Nada se rompe por desplegar sin credenciales.

**Pendiente para más adelante**: las *Real-time developer notifications* de
Play (vía Pub/Sub) son lo que avisa de renovaciones y cancelaciones sin que el
usuario abra la app. Hoy el acceso se refresca cuando la app arranca, que para
suscripciones semanales/anuales es suficiente, pero no es lo ideal.

---

### Copia de seguridad de Android

El manifest excluye los datos de la app del **respaldo en la nube**
(`res/xml/data_extraction_rules.xml` y `full_backup_content.xml`), pero
mantiene la **transferencia directa a un móvil nuevo**.

Sin esa exclusión, Android restauraba las preferencias al reinstalar, y eso
resucitaba progreso ya borrado con "Borrar mis datos": el borrado dejaba de
ser un borrado y la política de privacidad decía algo falso. Se detectó en un
móvil real, con una instalación "limpia" que trajo de vuelta la marca de
prueba gratuita consumida semanas antes.

> Consecuencia al probar: para una instalación realmente limpia hay que
> desinstalar, no solo borrar datos. Y en versiones anteriores a este cambio,
> reinstalar NO daba estado virgen.

### Informes de error

La app captura los errores de Dart y los manda a `app_error_reports` (migración
`20260901_error_reports.sql`, **pendiente de aplicar**). Se consultan desde el
Table Editor de Supabase: no hay panel ni alertas, así que conviene mirarlos a
mano los primeros días tras publicar.

Los **crashes nativos y los ANR** no pasan por ahí: esos los reporta Play
Console gratis en *Calidad → Android vitals*, sin necesidad de ningún SDK.

> No compiles con `--obfuscate` sin guardar los símbolos (`--split-debug-info`):
> las trazas llegarían ilegibles. Hoy el script de build no obfusca, así que no
> hay problema.

## 7. Antes de darle a "Publicar"

Lo que sigue pendiente y conviene resolver o decidir conscientemente:

- [x] ~~Verificación de compras en servidor~~ — hecha: Edge Function
      `verify-purchase` + tabla `user_entitlements`. Falta desplegarla con las
      credenciales de Play (requiere Play Console).
- [~] La prueba gratuita ya se controla en servidor (`trial_used`), pero solo
      sobrevive al reinstall si el usuario vinculó correo. Cierre definitivo:
      configurarla como oferta de prueba en Play Console.
- [x] ~~Sin crash reporting~~ — hecho: errores de Dart a `app_error_reports`
      (falta aplicar la migración) + Android vitals para lo nativo.
- [x] ~~Progreso ligado al dispositivo~~ — hecho: vinculación por código de 6
      dígitos al correo (Ajustes → «Guarda tu progreso»). Falta el SMTP y las
      plantillas para que los correos salgan.
- [ ] iOS sin configurar: faltan `CFBundleURLTypes` (los deep links
      `perueterno://` no funcionan) e `ITSAppUsesNonExemptEncryption`, y ni
      IAP ni TTS se han probado ahí.
