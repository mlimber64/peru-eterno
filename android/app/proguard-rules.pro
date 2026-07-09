# ── Flutter ──────────────────────────────────────────────────────────────────
# El Flutter Gradle Plugin ya aporta las reglas base del engine; aquí solo
# añadimos protecciones explícitas y silenciamos avisos de clases opcionales.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Google Play Billing / in_app_purchase ───────────────────────────────────
# El plugin usa la Billing Library vía reflexión; conservamos sus modelos.
-keep class com.android.billingclient.api.** { *; }
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.billingclient.**

# ── Modelos serializados con JSON (http) ────────────────────────────────────
# La app decodifica respuestas con dart:convert en el lado Dart, por lo que no
# requiere keeps de Gson/Moshi. Este bloque queda como recordatorio si en el
# futuro se añade alguna librería Android de (de)serialización por reflexión.
