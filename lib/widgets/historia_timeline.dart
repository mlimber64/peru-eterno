import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../data/historia_stages_repository.dart';
import '../models/timeline_item.dart';
import '../providers/language_provider.dart';
import 'app_state_views.dart';

class HistoriaTimeline extends StatefulWidget {
  final String lang;
  final void Function(TimelineItem item) onItemTap;

  const HistoriaTimeline({
    super.key,
    required this.lang,
    required this.onItemTap,
  });

  @override
  State<HistoriaTimeline> createState() => _HistoriaTimelineState();
}

class _HistoriaTimelineState extends State<HistoriaTimeline> {
  static const _kItemW = 108.0;
  static const _kScrollH = 212.0;
  static const _kCircleN = 60.0;
  static const _kCircleS = 76.0;

  final _scrollCtrl = ScrollController();
  int _selectedIdx = 0;
  List<TimelineItem>? _items;
  late Future<List<TimelineItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = HistoriaStagesRepository.loadTimeline().then((items) {
      if (mounted) _items = items;
      return items;
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final count = _items?.length ?? 0;
    if (count == 0) return;
    final idx = (_scrollCtrl.offset / _kItemW).round().clamp(0, count - 1);
    if (idx != _selectedIdx) setState(() => _selectedIdx = idx);
  }

  void _snapTo(int index) {
    final count = _items?.length ?? 1;
    final target =
        (index * _kItemW).clamp(0.0, (count - 1) * _kItemW.toDouble());
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimelineItem>>(
      future: _itemsFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const AppLoadingState(
            height: _kScrollH + 52,
            color: AppColors.worldHistoria,
            strokeWidth: 2,
          );
        }

        final items = snap.data!;
        final sw = MediaQuery.of(context).size.width;
        // Center-align first and last items
        final hPad = (sw - _kItemW) / 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.worldHistoria, Color(0x00C1440E)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context
                            .read<LanguageProvider>()
                            .t('timeline.historical')
                            .toUpperCase(),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.cremaPergamino,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '3000 a.C.  →  1821 d.C.',
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          color: AppColors.cremaPergamino.withOpacity(0.38),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Item name badge (shows active culture)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      key: ValueKey(_selectedIdx),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: items[_selectedIdx].color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: items[_selectedIdx].color.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        items[_selectedIdx].tituloFor(widget.lang),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: items[_selectedIdx].color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable timeline ──────────────────────────────────────
            Stack(
              children: [
                SizedBox(
                  height: _kScrollH,
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis != Axis.horizontal) return false;
                      final idx = (_scrollCtrl.offset / _kItemW)
                          .round()
                          .clamp(0, items.length - 1);
                      setState(() => _selectedIdx = idx);
                      _snapTo(idx);
                      return true;
                    },
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _selectedIdx = i);
                            _snapTo(i);
                            widget.onItemTap(items[i]);
                          },
                          child: _TimelineNode(
                            item: items[i],
                            isSelected: i == _selectedIdx,
                            isFirst: i == 0,
                            isLast: i == items.length - 1,
                            lang: widget.lang,
                            itemWidth: _kItemW,
                            circleNormal: _kCircleN,
                            circleSelected: _kCircleS,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Left edge fade
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.negoCacao,
                            AppColors.negoCacao.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Right edge fade
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.negoCacao.withOpacity(0),
                            AppColors.negoCacao,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Single timeline node ──────────────────────────────────────────────────────

class _TimelineNode extends StatelessWidget {
  final TimelineItem item;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final String lang;
  final double itemWidth;
  final double circleNormal;
  final double circleSelected;

  static const _kLineH = 20.0;
  static const _kDotN = 7.0;
  static const _kDotS = 11.0;

  const _TimelineNode({
    required this.item,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.lang,
    required this.itemWidth,
    required this.circleNormal,
    required this.circleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.color;
    final halfW = itemWidth / 2;

    return SizedBox(
      width: itemWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // ── Image circle (fixed-height slot, grows inward) ───────────
          SizedBox(
            height: circleSelected,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? circleSelected : circleNormal,
                height: isSelected ? circleSelected : circleNormal,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accent : accent.withOpacity(0.35),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accent.withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: item.imagePath != null
                      ? Image.asset(
                          item.imagePath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _gradientFill(accent),
                        )
                      : _gradientFill(accent),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Timeline bar + dot ───────────────────────────────────────
          SizedBox(
            height: _kLineH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Left segment
                Row(
                  children: [
                    Container(
                      width: halfW,
                      height: 1.5,
                      color: isFirst
                          ? Colors.transparent
                          : accent.withOpacity(0.28),
                    ),
                    Container(
                      width: halfW,
                      height: 1.5,
                      color: isLast
                          ? Colors.transparent
                          : accent.withOpacity(0.28),
                    ),
                  ],
                ),
                // Center dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? _kDotS : _kDotN,
                  height: isSelected ? _kDotS : _kDotN,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accent.withOpacity(0.55),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── Name ────────────────────────────────────────────────────
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: GoogleFonts.playfairDisplay(
              fontSize: isSelected ? 12.5 : 11.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : AppColors.cremaPergamino.withOpacity(0.55),
              height: 1.2,
            ),
            child: Text(
              item.tituloFor(lang),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 3),

          // ── Period ──────────────────────────────────────────────────
          Text(
            item.periodoFor(lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 9,
              color: isSelected
                  ? accent.withOpacity(0.85)
                  : AppColors.cremaPergamino.withOpacity(0.28),
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _gradientFill(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.55)!],
        ),
      ),
    );
  }
}
