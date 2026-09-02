import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_player_provider.dart';
import '../providers/language_provider.dart';

/// Mini-player flotante de la audio-historia, mostrado dentro del lector
/// (`HistoriaArticleDetailScreen`) mientras hay una reproducción activa para
/// el capítulo abierto.
class AudioBottomPlayerBar extends StatelessWidget {
  final String articleTitle;
  final String lang;
  final Color accent;

  const AudioBottomPlayerBar({
    super.key,
    required this.articleTitle,
    required this.lang,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerProvider>();
    final t = context.read<LanguageProvider>().t;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.marronProfundo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.graphic_eq_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('audio.now_playing'),
                      style: GoogleFonts.lato(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      articleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cremaPergamino,
                      ),
                    ),
                  ],
                ),
              ),
              _speedButton(context, audio, accent),
              _iconButton(
                icon: audio.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: accent,
                onTap: () => audio.isPlaying
                    ? audio.pause()
                    : audio.resume(lang),
              ),
              _iconButton(
                icon: Icons.stop_rounded,
                color: AppColors.cremaPergamino.withValues(alpha: 0.7),
                onTap: audio.stop,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: audio.progress,
              minHeight: 3,
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedButton(
      BuildContext context, AudioPlayerProvider audio, Color accent) {
    return GestureDetector(
      onTap: () => audio.cycleSpeed(lang),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          '${audio.speechRate}x',
          style: GoogleFonts.lato(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(left: 2),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
