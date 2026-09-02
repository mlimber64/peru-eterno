import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../data/legal_repository.dart';
import '../models/legal_document.dart';
import '../providers/language_provider.dart';

/// Muestra la política de privacidad o los términos de servicio dentro de la
/// app, en el idioma activo y sin necesidad de conexión (el texto viaja en
/// los assets). Las tiendas exigen además una URL pública equivalente: se
/// genera desde el MISMO JSON con `tool/generate_legal_html.dart`.
class LegalScreen extends StatefulWidget {
  final LegalDocType type;

  const LegalScreen({super.key, required this.type});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<LegalDocument> _future;
  String? _loadedLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarga si el usuario cambia de idioma con la pantalla abierta.
    final lang = context.watch<LanguageProvider>().currentLanguage;
    if (lang != _loadedLang) {
      _loadedLang = lang;
      _future = LegalRepository.instance.load(widget.type, lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.cremaPergamino,
        elevation: 0,
        title: Text(
          t(widget.type == LegalDocType.privacy
              ? 'premium.legal_privacy'
              : 'premium.legal_terms'),
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<LegalDocument>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.ocre),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    t('legal.load_error'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: AppColors.cremaPergamino.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }
            return _DocumentBody(doc: snapshot.data!, t: t);
          },
        ),
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  final LegalDocument doc;
  final String Function(String) t;

  const _DocumentBody({required this.doc, required this.t});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      children: [
        Text(
          doc.title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.update_rounded,
                size: 13, color: AppColors.ocre.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              '${t('legal.updated')} ${doc.updatedAt}',
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.ocre.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.marronProfundo,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.cremaPergamino.withValues(alpha: 0.06)),
          ),
          child: Text(
            doc.intro,
            style: GoogleFonts.lato(
              fontSize: 13.5,
              color: AppColors.cremaPergamino.withValues(alpha: 0.72),
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 26),
        for (final section in doc.sections) ...[
          Text(
            section.heading,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.ocre,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          for (final paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                paragraph,
                style: GoogleFonts.lato(
                  fontSize: 13.5,
                  color: AppColors.cremaPergamino.withValues(alpha: 0.65),
                  height: 1.7,
                ),
              ),
            ),
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 8),
        _ContactButton(email: doc.contactEmail, label: t('legal.contact')),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  final String email;
  final String label;

  const _ContactButton({required this.email, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ocre.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final uri = Uri(scheme: 'mailto', path: email);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ocre.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 18, color: AppColors.ocre),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ocre,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: AppColors.ocre.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
