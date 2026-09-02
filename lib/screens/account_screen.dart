import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import '../services/supabase_auth_service.dart';

/// Validación mínima en cliente de una dirección de correo.
///
/// No pretende validar según el RFC —eso lo hace el servidor—, sino evitar
/// gastar un envío (y un hueco del límite de correos por hora) en una
/// dirección obviamente mal escrita.
bool isPlausibleEmail(String value) {
  final email = value.trim();
  if (email.isEmpty || email.contains(' ')) return false;

  final at = email.indexOf('@');
  if (at <= 0 || at != email.lastIndexOf('@')) return false;
  if (at == email.length - 1) return false;

  final domain = email.substring(at + 1);
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.') &&
      !domain.contains('..');
}

/// Modo de entrada a la pantalla: vincular este dispositivo o recuperar el
/// progreso de una cuenta existente.
enum AccountMode {
  /// Este móvil tiene el progreso; se le pone un correo para no perderlo.
  link,

  /// Móvil nuevo (o app reinstalada); se entra con el correo de la cuenta.
  signIn,
}

/// Vincular la sesión anónima a un correo, o recuperar en este dispositivo el
/// progreso de una cuenta ya vinculada.
///
/// Es la pieza que faltaba para que el sync sirviera de algo: hasta ahora la
/// identidad era anónima y vivía en el almacenamiento de la app, así que
/// reinstalar generaba un `user_id` nuevo y el progreso subido quedaba
/// huérfano en el servidor.
///
/// Usa código de 6 dígitos por correo, no enlace mágico: sin deep links, igual
/// en Android y iOS, y sin que el usuario salga de la app.
class AccountScreen extends StatefulWidget {
  final AccountMode mode;

  const AccountScreen({super.key, this.mode = AccountMode.link});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  late AccountMode _mode = widget.mode;

  /// `false` mientras se pide el correo; `true` cuando ya se envió el código.
  bool _awaitingCode = false;
  bool _busy = false;
  String? _errorKey;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!isPlausibleEmail(email)) {
      setState(() => _errorKey = AuthActionOutcome.errInvalidEmail);
      return;
    }

    final auth = context.read<SupabaseAuthService>();
    setState(() {
      _busy = true;
      _errorKey = null;
    });

    final outcome = _mode == AccountMode.link
        ? await auth.sendLinkCode(email)
        : await auth.sendSignInCode(email);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorKey = outcome.messageKey;
      if (outcome.ok) _awaitingCode = true;
    });
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _errorKey = AuthActionOutcome.errInvalidCode);
      return;
    }

    final auth = context.read<SupabaseAuthService>();
    final t = context.read<LanguageProvider>().t;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _busy = true;
      _errorKey = null;
    });

    final outcome = _mode == AccountMode.link
        ? await auth.confirmLink(email, code)
        : await auth.confirmSignIn(email, code);

    if (!mounted) return;

    if (!outcome.ok) {
      setState(() {
        _busy = false;
        _errorKey = outcome.messageKey;
      });
      return;
    }

    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(t(_mode == AccountMode.link
              ? 'account.link_success'
              : 'account.signin_success')),
          backgroundColor: AppColors.verdeAndino,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _switchMode() {
    setState(() {
      _mode = _mode == AccountMode.link ? AccountMode.signIn : AccountMode.link;
      _awaitingCode = false;
      _codeController.clear();
      _errorKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final isLink = _mode == AccountMode.link;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.cremaPergamino,
        elevation: 0,
        title: Text(
          t('account.title'),
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          children: [
            Text(
              t(isLink ? 'account.link_title' : 'account.have_account'),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.cremaPergamino,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t(isLink ? 'account.link_intro' : 'account.have_account_intro'),
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppColors.cremaPergamino.withValues(alpha: 0.66),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),

            if (isLink) _Callout(text: t('account.link_warning')),
            if (!isLink) _Callout(text: t('account.merge_note'), soft: true),

            const SizedBox(height: 24),

            if (!_awaitingCode) ..._buildEmailStep(t) else ..._buildCodeStep(t),

            if (_errorKey != null) ...[
              const SizedBox(height: 16),
              Text(
                t(_errorKey!),
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: AppColors.terracota,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _switchMode,
                child: Text(
                  t(isLink ? 'account.have_account' : 'account.link_title'),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ocre,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.ocre.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEmailStep(String Function(String) t) => [
        _FieldLabel(t('account.email_label')),
        TextField(
          controller: _emailController,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _sendCode(),
          style: GoogleFonts.lato(
            fontSize: 15,
            color: AppColors.cremaPergamino,
          ),
          decoration: _inputDecoration(t('account.email_hint')),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: t(_mode == AccountMode.link
              ? 'account.send_code'
              : 'account.recover'),
          busy: _busy,
          onPressed: _sendCode,
        ),
      ];

  List<Widget> _buildCodeStep(String Function(String) t) => [
        Text(
          t('account.code_title'),
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${t('account.code_intro')} ${_emailController.text.trim()}',
          style: GoogleFonts.lato(
            fontSize: 13.5,
            color: AppColors.cremaPergamino.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        _FieldLabel(t('account.code_label')),
        TextField(
          controller: _codeController,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _verifyCode(),
          style: GoogleFonts.lato(
            fontSize: 22,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
            color: AppColors.cremaPergamino,
          ),
          decoration: _inputDecoration('······').copyWith(counterText: ''),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: t('account.verify'),
          busy: _busy,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _awaitingCode = false;
                      _codeController.clear();
                      _errorKey = null;
                    });
                  },
            child: Text(
              t('account.resend'),
              style: GoogleFonts.lato(
                fontSize: 13,
                color: AppColors.cremaPergamino.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ];

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.lato(
          fontSize: 15,
          color: AppColors.cremaPergamino.withValues(alpha: 0.25),
        ),
        filled: true,
        fillColor: AppColors.marronProfundo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.cremaPergamino.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.ocre.withValues(alpha: 0.7)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.cremaPergamino.withValues(alpha: 0.04)),
        ),
      );
}

// ── Piezas visuales ───────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.lato(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.cremaPergamino.withValues(alpha: 0.35),
          ),
        ),
      );
}

class _Callout extends StatelessWidget {
  final String text;

  /// `true` para el tono informativo (verde) en vez del de aviso (ocre).
  final bool soft;

  const _Callout({required this.text, this.soft = false});

  @override
  Widget build(BuildContext context) {
    final color = soft ? AppColors.verdeAndino : AppColors.ocre;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            soft ? Icons.merge_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: AppColors.cremaPergamino.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ocre,
          disabledBackgroundColor: AppColors.ocre.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
