# Plantillas de correo (Supabase Auth)

La app vincula la cuenta con un **código de 6 dígitos**, no con un enlace
mágico: no depende de deep links, se comporta igual en Android y iOS, y el
usuario nunca sale de la app.

**Las plantillas por defecto de Supabase no sirven para esto.** Traen solo
`{{ .ConfirmationURL }}` — un enlace — y no muestran el código. Si no se
cambian, el correo llega sin nada que teclear y el flujo queda inservible. La
variable que hace falta es `{{ .Token }}`.

## Paso 0 (obligatorio): SMTP propio

**Supabase no deja editar las plantillas hasta que haya un SMTP propio
configurado.** En Authentication → Emails aparece el aviso *"Set up custom SMTP
to edit templates"* y los campos Subject y Body están en solo lectura, con la
plantilla por defecto que solo manda un enlace. Sin SMTP no hay `{{ .Token }}`,
y sin token no hay código que teclear: el flujo entero queda inservible.

Así que el orden real es: **SMTP → plantillas → probar**.

Se configura en **Project Settings → Authentication → SMTP Settings**.

### Sin dominio propio (empezar ya)

[Brevo](https://www.brevo.com) permite verificar **una sola dirección de
correo** como remitente, sin necesidad de dominio, y su plan gratuito cubre
unos cientos de envíos al día — de sobra para el lanzamiento. Sirve
`perueterno.app@gmail.com` como remitente.

Contrapartida: al enviar "desde" una dirección de gmail.com a través de otro
proveedor, la firma no queda alineada con el dominio del remitente y algunos
correos pueden acabar en spam. Aceptable para empezar, no ideal a largo plazo.

Pasos concretos:

1. Cuenta en Brevo → **Senders, Domains & Dedicated IPs → Senders → Add a
   sender**: pon `perueterno.app@gmail.com` y confirma el correo que te llega.
2. **SMTP & API → SMTP** → genera una *SMTP key* (no es la contraseña de tu
   cuenta; se muestra una sola vez).
3. En Supabase, **Project Settings → Authentication → SMTP Settings**:

   | Campo | Valor |
   |---|---|
   | Host | `smtp-relay.brevo.com` |
   | Port | `587` |
   | Username | el login que muestra Brevo en SMTP & API (suele ser un número o tu correo) |
   | Password | la SMTP key generada |
   | Sender email | `perueterno.app@gmail.com` |
   | Sender name | `Perú Eterno` |

4. Guarda. El aviso *"Set up custom SMTP to edit templates"* desaparece y las
   plantillas pasan a ser editables.

### Con dominio propio (recomendado en cuanto se pueda)

Un dominio (~10-15 €/año) resuelve tres cosas a la vez: remitente propio del
tipo `hola@perueterno.app`, firmas SPF/DKIM correctas —con lo que los códigos
llegan a la bandeja y no a spam— y un sitio donde publicar la política de
privacidad sin depender de GitHub Pages. Con dominio,
[Resend](https://resend.com) es la opción más cómoda.

Los planes gratuitos cambian: comprueba los límites vigentes al registrarte.

## Paso 1: las plantillas

Con el SMTP ya configurado, en **Authentication → Emails → Templates** se
pueden editar. Hay que cambiar **dos**, porque la app usa dos flujos distintos:

| Plantilla | Cuándo se envía | Archivo |
|---|---|---|
| **Magic Link** | Recuperar el progreso en un dispositivo nuevo (`signInWithOtp`) | `magic_link.html` |
| **Change Email Address** | Vincular por primera vez un correo a la sesión anónima (`updateUser`) | `change_email.html` |

Pega el contenido de cada archivo en su plantilla y guarda. Los asuntos
sugeridos:

- Magic Link → `Il tuo codice Perú Eterno · Tu código · Your code`
- Change Email Address → `Conferma la tua email · Confirma tu correo · Confirm your email`

## Por qué son trilingües

Supabase permite una sola plantilla por proyecto, sin variantes por idioma,
y la app se usa en italiano, español e inglés. Con un código de 6 dígitos el
contenido es mínimo, así que caben las tres líneas sin que el correo resulte
pesado.

## Comprobar que funciona

Con SMTP y plantillas puestos: en la app, Ajustes → «Guarda tu progreso»,
escribe un correo tuyo y pide el código. Debe llegar un correo con seis
dígitos grandes. Si llega uno con un enlace y sin números, la plantilla no se
guardó.
