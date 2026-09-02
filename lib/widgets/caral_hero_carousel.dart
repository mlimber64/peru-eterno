import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Hero carousel editorial para Caral — 3 imágenes con autoplay lento y
/// swipe manual. Se usa solo en EraDetailScreen cuando era.id == 'caral'.
class CaralHeroCarousel extends StatefulWidget {
  const CaralHeroCarousel({super.key});

  static const List<String> _images = [
    'assets/images/content/caral/caral_desertico.webp',
    'assets/images/content/caral/sacerdote_ceremonial_andino.webp',
    'assets/images/content/caral/caral_nocturno_astronomico.webp',
  ];

  @override
  State<CaralHeroCarousel> createState() => _CaralHeroCarouselState();
}

class _CaralHeroCarouselState extends State<CaralHeroCarousel> {
  final _pageController = PageController();
  late final Timer _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      final next = (_current + 1) % CaralHeroCarousel._images.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.40;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Slides ──────────────────────────────────────────────────
              PageView.builder(
                controller: _pageController,
                itemCount: CaralHeroCarousel._images.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => Image.asset(
                  CaralHeroCarousel._images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.marronProfundo,
                    child: Center(
                      child: Icon(
                        Icons.landscape_rounded,
                        size: 56,
                        color: AppColors.ocre.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Dark gradient overlay ────────────────────────────────────
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.42, 1.0],
                  ),
                ),
              ),

              // ── Dot indicators ───────────────────────────────────────────
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    CaralHeroCarousel._images.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _current ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
