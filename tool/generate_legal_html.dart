// Genera las páginas legales públicas de `docs/` a partir de
// `assets/legal/legal.json` — la MISMA fuente que lee la app en
// `LegalRepository`. Google Play exige una URL pública de la política de
// privacidad para la ficha de la tienda; App Store la pide también en la
// ficha y en el flujo de suscripción.
//
// Uso:
//   dart run tool/generate_legal_html.dart
//
// Publicación (GitHub Pages):
//   1. Commitea `docs/`.
//   2. GitHub → Settings → Pages → Source: "Deploy from a branch",
//      branch `main`, carpeta `/docs`.
//   3. Las URLs quedan en:
//        https://mlimber64.github.io/peru-eterno/privacy.html
//        https://mlimber64.github.io/peru-eterno/terms.html
//      Esa primera es la que se pega en Play Console → Contenido de la app →
//      Política de privacidad.
//
// Nunca edites los .html a mano: se regeneran y perderías el cambio. Todo
// texto legal se corrige en assets/legal/legal.json.

import 'dart:convert';
import 'dart:io';

const _langs = ['es', 'it', 'en'];

const _langLabels = {'es': 'Español', 'it': 'Italiano', 'en': 'English'};

/// Etiquetas de la propia página (no del documento) por idioma.
const _uiStrings = {
  'es': {
    'updated': 'Actualizado el',
    'back': '← Perú Eterno',
    'other_doc_privacy': 'Política de Privacidad',
    'other_doc_terms': 'Términos de Servicio',
    'index_intro':
        'Documentos legales de la aplicación Perú Eterno, una app educativa sobre la historia del Perú.',
    'contact': 'Contacto:',
  },
  'it': {
    'updated': 'Aggiornato il',
    'back': '← Perú Eterno',
    'other_doc_privacy': 'Informativa sulla Privacy',
    'other_doc_terms': 'Termini di Servizio',
    'index_intro':
        "Documenti legali dell'applicazione Perú Eterno, un'app educativa sulla storia del Perù.",
    'contact': 'Contatto:',
  },
  'en': {
    'updated': 'Updated on',
    'back': '← Perú Eterno',
    'other_doc_privacy': 'Privacy Policy',
    'other_doc_terms': 'Terms of Service',
    'index_intro':
        'Legal documents for Perú Eterno, an educational app about the history of Peru.',
    'contact': 'Contact:',
  },
};

void main() {
  final source = File('assets/legal/legal.json');
  if (!source.existsSync()) {
    stderr.writeln(
        'No se encontró ${source.path}. Ejecuta el script desde la raíz del proyecto.');
    exit(1);
  }

  final data = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final email = data['contact_email'] as String;
  final updatedAt = data['updated_at'] as String;

  final outDir = Directory('docs');
  outDir.createSync(recursive: true);

  for (final docType in ['privacy', 'terms']) {
    final html = _renderDocument(
      data: data,
      docType: docType,
      email: email,
      updatedAt: updatedAt,
    );
    final file = File('${outDir.path}/$docType.html');
    file.writeAsStringSync(html);
    stdout.writeln('✔ ${file.path}');
  }

  final index = File('${outDir.path}/index.html');
  index.writeAsStringSync(_renderIndex(data: data, email: email));
  stdout.writeln('✔ ${index.path}');

  // Evita que GitHub Pages procese los archivos con Jekyll (innecesario y
  // provoca que ignore ficheros que empiecen por guion bajo).
  File('${outDir.path}/.nojekyll').writeAsStringSync('');
  stdout.writeln('✔ ${outDir.path}/.nojekyll');
}

String _renderDocument({
  required Map<String, dynamic> data,
  required String docType,
  required String email,
  required String updatedAt,
}) {
  final byLang = data[docType] as Map<String, dynamic>;
  final otherType = docType == 'privacy' ? 'terms' : 'privacy';

  final buffer = StringBuffer();
  for (final lang in _langs) {
    final doc = byLang[lang] as Map<String, dynamic>;
    final ui = _uiStrings[lang]!;
    final otherLabel = ui[otherType == 'privacy'
        ? 'other_doc_privacy'
        : 'other_doc_terms']!;

    buffer.writeln('<section class="doc" data-lang="$lang">');
    buffer.writeln('  <h1>${_esc(_fill(doc['title'] as String, email, updatedAt))}</h1>');
    buffer.writeln('  <p class="updated">${_esc(ui['updated']!)} $updatedAt</p>');
    buffer.writeln('  <p class="intro">${_esc(_fill(doc['intro'] as String, email, updatedAt))}</p>');

    for (final rawSection in doc['sections'] as List) {
      final section = rawSection as Map<String, dynamic>;
      buffer.writeln('  <h2>${_esc(_fill(section['h'] as String, email, updatedAt))}</h2>');
      for (final rawParagraph in section['p'] as List) {
        final text = _fill(rawParagraph as String, email, updatedAt);
        buffer.writeln('  <p>${_linkify(_esc(text), email)}</p>');
      }
    }

    buffer.writeln('  <p class="footer-nav">'
        '<a href="$otherType.html">$otherLabel</a> · '
        '<a href="mailto:$email">$email</a>'
        '</p>');
    buffer.writeln('</section>');
  }

  final title = (byLang['es'] as Map<String, dynamic>)['title'] as String;
  return _page(title: '$title · Perú Eterno', body: buffer.toString());
}

String _renderIndex({
  required Map<String, dynamic> data,
  required String email,
}) {
  final buffer = StringBuffer();
  for (final lang in _langs) {
    final ui = _uiStrings[lang]!;
    final privacyTitle =
        ((data['privacy'] as Map)[lang] as Map)['title'] as String;
    final termsTitle = ((data['terms'] as Map)[lang] as Map)['title'] as String;

    buffer.writeln('<section class="doc" data-lang="$lang">');
    buffer.writeln('  <h1>Perú Eterno</h1>');
    buffer.writeln('  <p class="intro">${_esc(ui['index_intro']!)}</p>');
    buffer.writeln('  <p><a class="doc-link" href="privacy.html">${_esc(privacyTitle)}</a></p>');
    buffer.writeln('  <p><a class="doc-link" href="terms.html">${_esc(termsTitle)}</a></p>');
    buffer.writeln('  <p class="footer-nav">${_esc(ui['contact']!)} '
        '<a href="mailto:$email">$email</a></p>');
    buffer.writeln('</section>');
  }
  return _page(title: 'Perú Eterno · Legal', body: buffer.toString());
}

/// Envoltorio HTML autocontenido (sin CSS ni JS externos), con selector de
/// idioma y paleta de la app.
String _page({required String title, required String body}) {
  final tabs = _langs
      .map((l) =>
          '<button type="button" data-target="$l">${_langLabels[l]}</button>')
      .join('\n      ');

  return '''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(title)}</title>
<style>
  :root {
    --ocre: #C8860A;
    --crema: #F5E6C8;
    --negro-cacao: #1A0F0A;
    --marron-profundo: #2C1810;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--negro-cacao);
    color: rgba(245, 230, 200, 0.72);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.7;
  }
  .wrap { max-width: 760px; margin: 0 auto; padding: 32px 20px 72px; }
  .langbar { display: flex; gap: 8px; margin-bottom: 28px; flex-wrap: wrap; }
  .langbar button {
    background: var(--marron-profundo);
    color: rgba(245, 230, 200, 0.55);
    border: 1px solid rgba(245, 230, 200, 0.1);
    border-radius: 999px;
    padding: 8px 16px;
    font: inherit;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
  }
  .langbar button[aria-pressed="true"] {
    background: rgba(200, 134, 10, 0.15);
    border-color: rgba(200, 134, 10, 0.6);
    color: var(--ocre);
  }
  .doc { display: none; }
  .doc.active { display: block; }
  h1 { color: var(--crema); font-size: 30px; line-height: 1.2; margin: 0 0 8px; }
  h2 { color: var(--ocre); font-size: 18px; margin: 32px 0 8px; }
  .updated { color: var(--ocre); font-size: 12px; font-weight: 700; letter-spacing: 0.5px; margin: 0 0 20px; }
  .intro {
    background: var(--marron-profundo);
    border: 1px solid rgba(245, 230, 200, 0.06);
    border-radius: 14px;
    padding: 16px;
  }
  p { margin: 0 0 12px; }
  a { color: var(--ocre); }
  .doc-link { font-size: 18px; font-weight: 700; }
  .footer-nav {
    margin-top: 40px;
    padding-top: 20px;
    border-top: 1px solid rgba(245, 230, 200, 0.08);
    font-size: 14px;
  }
</style>
</head>
<body>
  <div class="wrap">
    <nav class="langbar">
      $tabs
    </nav>
$body  </div>
<script>
  (function () {
    var buttons = document.querySelectorAll('.langbar button');
    var docs = document.querySelectorAll('.doc');
    function show(lang) {
      docs.forEach(function (d) { d.classList.toggle('active', d.dataset.lang === lang); });
      buttons.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.target === lang)); });
      document.documentElement.lang = lang;
    }
    buttons.forEach(function (b) {
      b.addEventListener('click', function () { show(b.dataset.target); });
    });
    var browser = (navigator.language || 'es').slice(0, 2);
    show(['es', 'it', 'en'].indexOf(browser) >= 0 ? browser : 'es');
  })();
</script>
</body>
</html>
''';
}

String _fill(String value, String email, String updatedAt) =>
    value.replaceAll('{email}', email).replaceAll('{updated_at}', updatedAt);

String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Convierte el email de contacto en un enlace `mailto:` allí donde aparezca.
String _linkify(String escapedText, String email) =>
    escapedText.replaceAll(email, '<a href="mailto:$email">$email</a>');
